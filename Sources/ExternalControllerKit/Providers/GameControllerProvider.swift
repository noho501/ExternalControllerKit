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
            bind(button: gamepad.buttonA, inputId: "button_a", deviceId: deviceId)
            bind(button: gamepad.buttonB, inputId: "button_b", deviceId: deviceId)
            bind(button: gamepad.buttonX, inputId: "button_x", deviceId: deviceId)
            bind(button: gamepad.buttonY, inputId: "button_y", deviceId: deviceId)
            bind(button: gamepad.leftShoulder, inputId: "left_shoulder", deviceId: deviceId)
            bind(button: gamepad.rightShoulder, inputId: "right_shoulder", deviceId: deviceId)
            bind(trigger: gamepad.leftTrigger, inputId: "left_trigger", deviceId: deviceId)
            bind(trigger: gamepad.rightTrigger, inputId: "right_trigger", deviceId: deviceId)
            if let leftThumbstickButton = gamepad.leftThumbstickButton {
                bind(button: leftThumbstickButton, inputId: "left_stick_button", deviceId: deviceId)
            }
            if let rightThumbstickButton = gamepad.rightThumbstickButton {
                bind(button: rightThumbstickButton, inputId: "right_stick_button", deviceId: deviceId)
            }
            bind(dpad: gamepad.dpad, deviceId: deviceId)
            bind(thumbstick: gamepad.leftThumbstick, xInputId: "left_stick_x", yInputId: "left_stick_y", deviceId: deviceId)
            bind(thumbstick: gamepad.rightThumbstick, xInputId: "right_stick_x", yInputId: "right_stick_y", deviceId: deviceId)
        }
        if let micro = controller.microGamepad {
            bind(button: micro.buttonA, inputId: "button_a", deviceId: deviceId)
            bind(button: micro.buttonX, inputId: "button_x", deviceId: deviceId)
            bind(dpad: micro.dpad, deviceId: deviceId)
        }
    }

    private func bind(button: GCControllerButtonInput, inputId: String, deviceId: String) {
        button.valueChangedHandler = { [weak self] _, _, isPressed in
            self?.emit(deviceId: deviceId, inputId: inputId, value: .button(isPressed))
        }
    }

    private func bind(trigger: GCControllerButtonInput, inputId: String, deviceId: String) {
        trigger.valueChangedHandler = { [weak self] _, value, _ in
            self?.emit(deviceId: deviceId, inputId: inputId, value: .axis(Double(value)))
        }
    }

    private func bind(dpad: GCControllerDirectionPad, deviceId: String) {
        dpad.up.valueChangedHandler = { [weak self] _, _, isPressed in self?.emit(deviceId: deviceId, inputId: "dpad_up", value: .button(isPressed)) }
        dpad.down.valueChangedHandler = { [weak self] _, _, isPressed in self?.emit(deviceId: deviceId, inputId: "dpad_down", value: .button(isPressed)) }
        dpad.left.valueChangedHandler = { [weak self] _, _, isPressed in self?.emit(deviceId: deviceId, inputId: "dpad_left", value: .button(isPressed)) }
        dpad.right.valueChangedHandler = { [weak self] _, _, isPressed in self?.emit(deviceId: deviceId, inputId: "dpad_right", value: .button(isPressed)) }
    }

    private func bind(thumbstick: GCControllerDirectionPad, xInputId: String, yInputId: String, deviceId: String) {
        thumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.emit(deviceId: deviceId, inputId: xInputId, value: .axis(Double(xValue)))
            self?.emit(deviceId: deviceId, inputId: yInputId, value: .axis(Double(yValue)))
        }
    }

    private func emit(deviceId: String, inputId: String, value: InputValue) {
        logger.log(level: .debug, message: "GameController event \(deviceId) \(inputId) value=\(value)")
        delegate?.provider(self, didReceive: InputEvent(deviceId: deviceId, inputId: inputId, value: value))
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
