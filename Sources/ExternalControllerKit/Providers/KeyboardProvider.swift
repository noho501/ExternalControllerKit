import Foundation
#if canImport(GameController)
import GameController
#endif

public final class KeyboardProvider: ExternalControllerProvider {
    public weak var delegate: (any ExternalControllerProviderDelegate)?
    public let providerKind: DeviceKind = .keyboard
    public var connectedDevices: [Device] { Array(devices.values).sorted { $0.name < $1.name } }

    private let logger: any ExternalControllerLogger
    private var devices: [String: Device] = [:]
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
        observers.append(center.addObserver(forName: .GCKeyboardDidConnect, object: nil, queue: .main) { [weak self] _ in
            self?.refreshConnectedDevices()
        })
        observers.append(center.addObserver(forName: .GCKeyboardDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            self?.refreshConnectedDevices()
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
        let previousIds = Set(devices.keys)
        var refreshed: [String: Device] = [:]
        if let keyboard = GCKeyboard.coalesced {
            let device = makeDevice(for: keyboard)
            refreshed[device.id] = device
            bindKeyboardInput(keyboard, deviceId: device.id)
        }
        devices = refreshed
        for device in connectedDevices {
            delegate?.provider(self, didConnect: device)
        }
        for removedId in previousIds.subtracting(refreshed.keys) {
            delegate?.provider(self, didDisconnect: Device(id: removedId, name: removedId, kind: .keyboard))
        }
        #endif
    }

    #if canImport(GameController)
    private func bindKeyboardInput(_ keyboard: GCKeyboard, deviceId: String) {
        keyboard.keyboardInput?.keyChangedHandler = { [weak self] _, keyCode, _, isPressed in
            guard let self else { return }
            let buttonId = Self.normalizedButtonId(for: keyCode)
            logger.log(level: .debug, message: "Keyboard event \(deviceId) \(buttonId) pressed=\(isPressed)")
            delegate?.provider(self, didReceive: ButtonEvent(deviceId: deviceId, buttonId: buttonId, isPressed: isPressed))
        }
    }

    private func makeDevice(for keyboard: GCKeyboard) -> Device {
        let id = "gc_keyboard_coalesced"
        let name = keyboard.coalesced == nil ? "Keyboard" : "System Keyboard"
        return Device(id: id, name: name, kind: .keyboard)
    }

    private static func normalizedButtonId(for keyCode: GCKeyCode) -> String {
        let description = String(describing: keyCode)
        if description.hasPrefix("key"), let scalar = description.last {
            return "KEY_\(String(scalar).uppercased())"
        }
        if let functionIndex = Int(description.dropFirst()), description.first == "f" {
            return "F\(functionIndex)"
        }
        switch description {
        case "zero": return "DIGIT_0"
        case "one": return "DIGIT_1"
        case "two": return "DIGIT_2"
        case "three": return "DIGIT_3"
        case "four": return "DIGIT_4"
        case "five": return "DIGIT_5"
        case "six": return "DIGIT_6"
        case "seven": return "DIGIT_7"
        case "eight": return "DIGIT_8"
        case "nine": return "DIGIT_9"
        case "spacebar": return "SPACE"
        case "tab": return "TAB"
        case "returnOrEnter": return "ENTER"
        case "escape": return "ESCAPE"
        case "deleteOrBackspace": return "BACKSPACE"
        case "leftArrow": return "ARROW_LEFT"
        case "rightArrow": return "ARROW_RIGHT"
        case "upArrow": return "ARROW_UP"
        case "downArrow": return "ARROW_DOWN"
        case "leftShift": return "LEFT_SHIFT"
        case "rightShift": return "RIGHT_SHIFT"
        case "leftControl": return "LEFT_CONTROL"
        case "rightControl": return "RIGHT_CONTROL"
        case "leftAlt": return "LEFT_OPTION"
        case "rightAlt": return "RIGHT_OPTION"
        case "leftGUI": return "LEFT_COMMAND"
        case "rightGUI": return "RIGHT_COMMAND"
        default: return "KEY_RAW_\(keyCode.rawValue)"
        }
    }
    #endif
}
