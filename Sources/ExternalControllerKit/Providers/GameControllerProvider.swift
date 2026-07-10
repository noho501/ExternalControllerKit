import Foundation
#if canImport(GameController)
import GameController
#endif

public final class GameControllerProvider: ExternalControllerProvider {
    public weak var delegate: (any ExternalControllerProviderDelegate)?
    public let providerKind: DeviceKind = .gameController
    public var connectedDevices: [Device] { Array(devices.values).sorted { $0.name < $1.name } }

    private var devices: [String: Device] = [:]
    private let logger: any ExternalControllerLogger
    #if canImport(GameController)
    private var observers: [NSObjectProtocol] = []
    private let thumbstickThreshold: Float = 0.6
    #endif

    public init(logger: any ExternalControllerLogger = DisabledExternalControllerLogger()) {
        self.logger = logger
    }

    public func start() {
        #if canImport(GameController)
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.register(controller: controller)
        })
        observers.append(center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.unregister(controller: controller)
        })
        refreshConnectedDevices()
        #endif
    }

    public func stop() {
        #if canImport(GameController)
        let center = NotificationCenter.default
        observers.forEach(center.removeObserver)
        observers.removeAll()
        devices.removeAll()
        #endif
    }

    public func refreshConnectedDevices() {
        #if canImport(GameController)
        var refreshed: [String: Device] = [:]
        for controller in GCController.controllers() {
            let device = makeDevice(for: controller)
            refreshed[device.id] = device
            bindInputs(for: controller, deviceId: device.id)
            logger.log(level: .debug, message: "Detected controller \(device.name) [\(device.id)]")
        }
        let removedIds = Set(devices.keys).subtracting(refreshed.keys)
        devices = refreshed
        for device in connectedDevices {
            delegate?.provider(self, didConnect: device)
        }
        for removedId in removedIds {
            delegate?.provider(self, didDisconnect: Device(id: removedId, name: removedId, kind: .gameController))
        }
        #endif
    }

    #if canImport(GameController)
    private func register(controller: GCController) {
        let device = makeDevice(for: controller)
        devices[device.id] = device
        bindInputs(for: controller, deviceId: device.id)
        delegate?.provider(self, didConnect: device)
    }

    private func unregister(controller: GCController) {
        let device = makeDevice(for: controller)
        devices.removeValue(forKey: device.id)
        delegate?.provider(self, didDisconnect: device)
    }

    private func bindInputs(for controller: GCController, deviceId: String) {
        if let gamepad = controller.extendedGamepad {
            bind(button: gamepad.buttonA, buttonId: "A", deviceId: deviceId)
            bind(button: gamepad.buttonB, buttonId: "B", deviceId: deviceId)
            bind(button: gamepad.buttonX, buttonId: "X", deviceId: deviceId)
            bind(button: gamepad.buttonY, buttonId: "Y", deviceId: deviceId)
            bind(button: gamepad.leftShoulder, buttonId: "L1", deviceId: deviceId)
            bind(button: gamepad.rightShoulder, buttonId: "R1", deviceId: deviceId)
            bind(button: gamepad.leftTrigger, buttonId: "L2", deviceId: deviceId)
            bind(button: gamepad.rightTrigger, buttonId: "R2", deviceId: deviceId)
            if let leftThumbstickButton = gamepad.leftThumbstickButton {
                bind(button: leftThumbstickButton, buttonId: "L3", deviceId: deviceId)
            }
            if let rightThumbstickButton = gamepad.rightThumbstickButton {
                bind(button: rightThumbstickButton, buttonId: "R3", deviceId: deviceId)
            }
            bind(dpad: gamepad.dpad, prefix: "DPAD", deviceId: deviceId)
            bind(thumbstick: gamepad.leftThumbstick, prefix: "LEFT_STICK", deviceId: deviceId)
            bind(thumbstick: gamepad.rightThumbstick, prefix: "RIGHT_STICK", deviceId: deviceId)
        }
        if let micro = controller.microGamepad {
            bind(button: micro.buttonA, buttonId: "A", deviceId: deviceId)
            bind(button: micro.buttonX, buttonId: "X", deviceId: deviceId)
            bind(dpad: micro.dpad, prefix: "DPAD", deviceId: deviceId)
        }
    }

    private func bind(button: GCControllerButtonInput, buttonId: String, deviceId: String) {
        button.valueChangedHandler = { [weak self] _, _, isPressed in
            self?.emit(deviceId: deviceId, buttonId: buttonId, isPressed: isPressed)
        }
    }

    private func bind(dpad: GCControllerDirectionPad, prefix: String, deviceId: String) {
        dpad.up.valueChangedHandler = { [weak self] _, _, isPressed in self?.emit(deviceId: deviceId, buttonId: "\(prefix)_UP", isPressed: isPressed) }
        dpad.down.valueChangedHandler = { [weak self] _, _, isPressed in self?.emit(deviceId: deviceId, buttonId: "\(prefix)_DOWN", isPressed: isPressed) }
        dpad.left.valueChangedHandler = { [weak self] _, _, isPressed in self?.emit(deviceId: deviceId, buttonId: "\(prefix)_LEFT", isPressed: isPressed) }
        dpad.right.valueChangedHandler = { [weak self] _, _, isPressed in self?.emit(deviceId: deviceId, buttonId: "\(prefix)_RIGHT", isPressed: isPressed) }
    }

    private func bind(thumbstick: GCControllerDirectionPad, prefix: String, deviceId: String) {
        thumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            guard let self else { return }
            emit(deviceId: deviceId, buttonId: "\(prefix)_LEFT", isPressed: xValue <= -thumbstickThreshold)
            emit(deviceId: deviceId, buttonId: "\(prefix)_RIGHT", isPressed: xValue >= thumbstickThreshold)
            emit(deviceId: deviceId, buttonId: "\(prefix)_DOWN", isPressed: yValue <= -thumbstickThreshold)
            emit(deviceId: deviceId, buttonId: "\(prefix)_UP", isPressed: yValue >= thumbstickThreshold)
        }
    }

    private func emit(deviceId: String, buttonId: String, isPressed: Bool) {
        logger.log(level: .debug, message: "GameController event \(deviceId) \(buttonId) pressed=\(isPressed)")
        delegate?.provider(self, didReceive: ButtonEvent(deviceId: deviceId, buttonId: buttonId, isPressed: isPressed))
    }

    private func makeDevice(for controller: GCController) -> Device {
        let vendor = controller.vendorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let product = controller.productCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let stableSeed = [vendor, product, String(describing: type(of: controller))]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "|")
        let name = vendor?.isEmpty == false ? vendor! : (product.isEmpty ? "Game Controller" : product)
        return Device(id: "gc_\(stableSeed.replacingOccurrences(of: " ", with: "_").lowercased())", name: name, kind: .gameController, batteryLevel: controller.battery?.batteryLevel)
    }
    #endif
}
