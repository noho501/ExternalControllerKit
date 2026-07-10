import Foundation

public protocol ExternalControllerDelegate: AnyObject {
    func externalController(_ controller: ExternalController, didChangeConnectedDevices devices: [Device])
    func externalController(_ controller: ExternalController, didChangeMappings mappings: [Mapping])
    func externalController(_ controller: ExternalController, didChangeState state: ManagerState)
    func externalController(_ controller: ExternalController, didTriggerAction actionId: String, deviceId: String, buttonId: String)
}

@MainActor
public final class ExternalController: ExternalControllerProviderDelegate {
    public static let shared = ExternalController()

    public weak var delegate: (any ExternalControllerDelegate)?
    public var onDevicesChanged: (([Device]) -> Void)?
    public var onMappingsChanged: (([Mapping]) -> Void)?
    public var onStateChanged: ((ManagerState) -> Void)?
    public var onActionTriggered: ((String, String, String) -> Void)?

    public private(set) var connectedDevices: [Device] = []
    public private(set) var selectedDeviceId: String?
    public private(set) var isInputEnabled = true
    public private(set) var state: ManagerState = .idle
    public private(set) var actionDefinitions: [ActionDefinition] = []

    private let providers: [any ExternalControllerProvider]
    private let storage: any MappingStorage
    private let notificationCenter: NotificationCenter
    private let notificationConfiguration: ExternalControllerNotificationConfiguration
    private let logger: any ExternalControllerLogger
    private var mappings: [Mapping]
    private var observations: [UUID: ObservationHandlers] = [:]

    public init(
        providers: [any ExternalControllerProvider] = ExternalController.defaultProviders(),
        storage: any MappingStorage = UserDefaultsMappingStorage(),
        notificationCenter: NotificationCenter = .default,
        notificationConfiguration: ExternalControllerNotificationConfiguration = .default,
        logger: any ExternalControllerLogger = DisabledExternalControllerLogger()
    ) {
        self.providers = providers
        self.storage = storage
        self.notificationCenter = notificationCenter
        self.notificationConfiguration = notificationConfiguration
        self.logger = logger
        self.mappings = (try? storage.loadMappings()) ?? []
        for provider in providers {
            provider.delegate = nil
        }
        synchronizeConnectedDevices()
    }

    public func start() {
        for provider in providers {
            provider.delegate = self
            provider.start()
        }
        synchronizeConnectedDevices(notify: true)
        publishMappingsChanged()
        publishStateChanged()
    }

    public func stop() {
        stopListening()
        for provider in providers {
            provider.stop()
            provider.delegate = nil
        }
        connectedDevices = []
        selectedDeviceId = nil
        publishDevicesChanged()
    }

    public func configure(actions: [ActionDefinition]) {
        actionDefinitions = actions.sorted { lhs, rhs in
            let lhsOrder = lhs.sortOrder ?? .max
            let rhsOrder = rhs.sortOrder ?? .max
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
        }
    }

    public func refreshConnectedDevices() {
        providers.forEach { $0.refreshConnectedDevices() }
        synchronizeConnectedDevices(notify: true)
    }

    public func setInputEnabled(_ isEnabled: Bool) {
        isInputEnabled = isEnabled
    }

    public func setSelectedDevice(id: String?) {
        let availableIds = Set(connectedDevices.map(\.id))
        selectedDeviceId = id.flatMap { availableIds.contains($0) ? $0 : nil } ?? connectedDevices.first?.id
        publishDevicesChanged()
    }

    public func startListening(for actionId: String) {
        if case .listening(let currentActionId) = state, currentActionId == actionId {
            return
        }
        state = .listening(actionId: actionId)
        publishStateChanged()
    }

    public func stopListening() {
        guard state != .idle else { return }
        state = .idle
        publishStateChanged()
    }

    public func assign(deviceId: String, buttonId: String, actionId: String) {
        assignInternal(deviceId: deviceId, buttonId: buttonId, actionId: actionId)
        publishMappingsChanged()
    }

    public func mapping(for actionId: String, deviceId: String) -> Mapping? {
        mappings.first { $0.actionId == actionId && $0.deviceId == deviceId }
    }

    public func mappings(for deviceId: String) -> [Mapping] {
        mappings.filter { $0.deviceId == deviceId }
    }

    public func allMappings() -> [Mapping] {
        mappings
    }

    public func resetAllMappings() {
        mappings.removeAll()
        persistMappings(clearWhenEmpty: true)
        publishMappingsChanged()
    }

    public func observe(
        onDevicesChanged: (([Device]) -> Void)? = nil,
        onMappingsChanged: (([Mapping]) -> Void)? = nil,
        onStateChanged: ((ManagerState) -> Void)? = nil,
        onActionTriggered: ((String, String, String) -> Void)? = nil
    ) -> ExternalControllerObservation {
        let id = UUID()
        observations[id] = ObservationHandlers(
            onDevicesChanged: onDevicesChanged,
            onMappingsChanged: onMappingsChanged,
            onStateChanged: onStateChanged,
            onActionTriggered: onActionTriggered
        )
        return ExternalControllerObservation { [weak self] in
            self?.observations.removeValue(forKey: id)
        }
    }

    public func provider(_ provider: any ExternalControllerProvider, didReceive event: ButtonEvent) {
        guard event.isPressed else { return }

        switch state {
        case .listening(let actionId):
            guard event.deviceId == selectedDeviceId else { return }
            assignInternal(deviceId: event.deviceId, buttonId: event.buttonId, actionId: actionId)
            publishMappingsChanged()
            state = .idle
            publishStateChanged()
        case .idle:
            guard isInputEnabled, let mapping = mappings.first(where: { $0.deviceId == event.deviceId && $0.buttonId == event.buttonId }) else {
                return
            }
            publishActionTriggered(actionId: mapping.actionId, deviceId: event.deviceId, buttonId: event.buttonId)
        }
    }

    public func provider(_ provider: any ExternalControllerProvider, didConnect device: Device) {
        logger.log(level: .debug, message: "Connected device \(device.id)")
        synchronizeConnectedDevices(notify: true)
    }

    public func provider(_ provider: any ExternalControllerProvider, didDisconnect device: Device) {
        logger.log(level: .debug, message: "Disconnected device \(device.id)")
        synchronizeConnectedDevices(notify: true)
    }

    public static func defaultProviders(logger: any ExternalControllerLogger = DisabledExternalControllerLogger()) -> [any ExternalControllerProvider] {
        [
            GameControllerProvider(logger: logger),
            KeyboardProvider(logger: logger),
            MIDIProvider(logger: logger)
        ]
    }

    private func synchronizeConnectedDevices(notify: Bool = false) {
        connectedDevices = providers.flatMap(\.connectedDevices)
            .sorted { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        if let selectedDeviceId, !connectedDevices.contains(where: { $0.id == selectedDeviceId }) {
            self.selectedDeviceId = connectedDevices.first?.id
        } else if selectedDeviceId == nil {
            selectedDeviceId = connectedDevices.first?.id
        }
        if notify {
            publishDevicesChanged()
        }
    }

    private func assignInternal(deviceId: String, buttonId: String, actionId: String) {
        mappings.removeAll { mapping in
            (mapping.deviceId == deviceId && mapping.buttonId == buttonId) ||
            (mapping.deviceId == deviceId && mapping.actionId == actionId)
        }
        mappings.append(Mapping(deviceId: deviceId, buttonId: buttonId, actionId: actionId))
        persistMappings(clearWhenEmpty: false)
    }

    private func persistMappings(clearWhenEmpty: Bool) {
        do {
            if clearWhenEmpty && mappings.isEmpty {
                try storage.clearMappings()
            } else {
                try storage.saveMappings(mappings)
            }
        } catch {
            logger.log(level: .error, message: "Failed to persist mappings: \(error.localizedDescription)")
        }
    }

    private func publishDevicesChanged() {
        delegate?.externalController(self, didChangeConnectedDevices: connectedDevices)
        onDevicesChanged?(connectedDevices)
        for observer in observations.values {
            observer.onDevicesChanged?(connectedDevices)
        }
        notificationCenter.post(
            name: notificationConfiguration.devicesChanged,
            object: self,
            userInfo: [
                ExternalControllerNotificationUserInfoKey.devices: connectedDevices
            ]
        )
    }

    private func publishMappingsChanged() {
        delegate?.externalController(self, didChangeMappings: mappings)
        onMappingsChanged?(mappings)
        for observer in observations.values {
            observer.onMappingsChanged?(mappings)
        }
        notificationCenter.post(
            name: notificationConfiguration.mappingsChanged,
            object: self,
            userInfo: [
                ExternalControllerNotificationUserInfoKey.mappings: mappings
            ]
        )
    }

    private func publishStateChanged() {
        delegate?.externalController(self, didChangeState: state)
        onStateChanged?(state)
        for observer in observations.values {
            observer.onStateChanged?(state)
        }
        notificationCenter.post(
            name: notificationConfiguration.stateChanged,
            object: self,
            userInfo: [
                ExternalControllerNotificationUserInfoKey.state: state
            ]
        )
    }

    private func publishActionTriggered(actionId: String, deviceId: String, buttonId: String) {
        delegate?.externalController(self, didTriggerAction: actionId, deviceId: deviceId, buttonId: buttonId)
        onActionTriggered?(actionId, deviceId, buttonId)
        for observer in observations.values {
            observer.onActionTriggered?(actionId, deviceId, buttonId)
        }
        notificationCenter.post(
            name: notificationConfiguration.actionTriggered,
            object: self,
            userInfo: [
                ExternalControllerNotificationUserInfoKey.actionId: actionId,
                ExternalControllerNotificationUserInfoKey.deviceId: deviceId,
                ExternalControllerNotificationUserInfoKey.buttonId: buttonId
            ]
        )
    }
}

private struct ObservationHandlers {
    let onDevicesChanged: (([Device]) -> Void)?
    let onMappingsChanged: (([Mapping]) -> Void)?
    let onStateChanged: ((ManagerState) -> Void)?
    let onActionTriggered: ((String, String, String) -> Void)?
}
