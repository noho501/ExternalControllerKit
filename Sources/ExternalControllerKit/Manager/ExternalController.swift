import Foundation

public protocol ExternalControllerDelegate: AnyObject {
    func externalController(_ controller: ExternalController, didChangeConnectedDevices devices: [Device])
    func externalController(_ controller: ExternalController, didChangeMappings mappings: [Mapping])
    func externalController(_ controller: ExternalController, didChangeState state: ManagerState)
    func externalController(_ controller: ExternalController, didTriggerAction actionId: String, deviceId: String, inputId: String, value: InputValue)
    func externalController(_ controller: ExternalController, didTriggerAction actionId: String, deviceId: String, buttonId: String)
}

public extension ExternalControllerDelegate {
    func externalController(_ controller: ExternalController, didTriggerAction actionId: String, deviceId: String, inputId: String, value: InputValue) {
        guard value.isDigitalActivation else { return }
        externalController(controller, didTriggerAction: actionId, deviceId: deviceId, buttonId: inputId)
    }

    func externalController(_ controller: ExternalController, didTriggerAction actionId: String, deviceId: String, buttonId: String) {}
}

@MainActor
public final class ExternalController: ExternalControllerProviderDelegate {
    public static let shared = ExternalController()

    public weak var delegate: (any ExternalControllerDelegate)?
    public var onDevicesChanged: (([Device]) -> Void)?
    public var onMappingsChanged: (([Mapping]) -> Void)?
    public var onStateChanged: ((ManagerState) -> Void)?
    public var onActionTriggered: ((String, String, String, InputValue) -> Void)?

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

    public func assign(deviceId: String, inputId: String, actionId: String) {
        assignInternal(deviceId: deviceId, inputId: inputId, actionId: actionId)
        publishMappingsChanged()
    }

    @available(*, deprecated, renamed: "assign(deviceId:inputId:actionId:)")
    public func assign(deviceId: String, buttonId: String, actionId: String) {
        assign(deviceId: deviceId, inputId: buttonId, actionId: actionId)
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
        onActionTriggered: ((String, String, String, InputValue) -> Void)? = nil
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

    public func provider(_ provider: any ExternalControllerProvider, didReceive event: InputEvent) {
        switch state {
        case .listening(let actionId):
            guard event.deviceId == selectedDeviceId, event.value.isDigitalActivation else { return }
            assignInternal(deviceId: event.deviceId, inputId: event.inputId, actionId: actionId)
            publishMappingsChanged()
            state = .idle
            publishStateChanged()
        case .idle:
            guard isInputEnabled else { return }
            if event.value.kind == "button", event.value.boolValue != true {
                return
            }
            guard let mapping = mappings.first(where: { $0.deviceId == event.deviceId && $0.inputId == event.inputId }) else {
                return
            }
            publishActionTriggered(actionId: mapping.actionId, deviceId: event.deviceId, inputId: event.inputId, value: event.value)
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

    private func assignInternal(deviceId: String, inputId: String, actionId: String) {
        mappings.removeAll { mapping in
            (mapping.deviceId == deviceId && mapping.inputId == inputId) ||
            (mapping.deviceId == deviceId && mapping.actionId == actionId)
        }
        mappings.append(Mapping(deviceId: deviceId, inputId: inputId, actionId: actionId))
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

    private func publishActionTriggered(actionId: String, deviceId: String, inputId: String, value: InputValue) {
        delegate?.externalController(self, didTriggerAction: actionId, deviceId: deviceId, inputId: inputId, value: value)
        onActionTriggered?(actionId, deviceId, inputId, value)
        for observer in observations.values {
            observer.onActionTriggered?(actionId, deviceId, inputId, value)
        }
        notificationCenter.post(
            name: notificationConfiguration.actionTriggered,
            object: self,
            userInfo: [
                ExternalControllerNotificationUserInfoKey.actionId: actionId,
                ExternalControllerNotificationUserInfoKey.deviceId: deviceId,
                ExternalControllerNotificationUserInfoKey.inputId: inputId,
                ExternalControllerNotificationUserInfoKey.buttonId: inputId,
                ExternalControllerNotificationUserInfoKey.inputValue: value
            ]
        )
    }
}

private struct ObservationHandlers {
    let onDevicesChanged: (([Device]) -> Void)?
    let onMappingsChanged: (([Mapping]) -> Void)?
    let onStateChanged: ((ManagerState) -> Void)?
    let onActionTriggered: ((String, String, String, InputValue) -> Void)?
}
