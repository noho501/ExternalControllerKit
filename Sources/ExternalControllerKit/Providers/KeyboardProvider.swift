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
            let device = makeDevice()
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
        keyboard.keyboardInput?.keyChangedHandler = { [weak self] _, _, keyCode, isPressed in
            guard let self else { return }
            let inputId = Self.normalizedInputId(for: keyCode)
            logger.log(level: .debug, message: "Keyboard event \(deviceId) \(inputId) pressed=\(isPressed)")
            delegate?.provider(self, didReceive: InputEvent(deviceId: deviceId, inputId: inputId, value: .button(isPressed)))
        }
    }

    private func makeDevice() -> Device {
       return Device(
            id: "gc_keyboard",
            name: "Keyboard",
            kind: .keyboard
        )
    }

    private static func normalizedInputId(for keyCode: GCKeyCode) -> String {
        let description = String(describing: keyCode)
        if description.hasPrefix("key"), let scalar = description.last {
            return "key_\(String(scalar).lowercased())"
        }
        if let functionIndex = Int(description.dropFirst()), description.first == "f" {
            return "key_f\(functionIndex)"
        }
        switch description {
        case "zero": return "key_0"
        case "one": return "key_1"
        case "two": return "key_2"
        case "three": return "key_3"
        case "four": return "key_4"
        case "five": return "key_5"
        case "six": return "key_6"
        case "seven": return "key_7"
        case "eight": return "key_8"
        case "nine": return "key_9"
        case "spacebar": return "key_space"
        case "tab": return "key_tab"
        case "returnOrEnter": return "key_enter"
        case "escape": return "key_escape"
        case "deleteOrBackspace": return "key_backspace"
        case "leftArrow": return "key_left_arrow"
        case "rightArrow": return "key_right_arrow"
        case "upArrow": return "key_up_arrow"
        case "downArrow": return "key_down_arrow"
        case "leftShift": return "key_left_shift"
        case "rightShift": return "key_right_shift"
        case "leftControl": return "key_left_control"
        case "rightControl": return "key_right_control"
        case "leftAlt": return "key_left_option"
        case "rightAlt": return "key_right_option"
        case "leftGUI": return "key_left_command"
        case "rightGUI": return "key_right_command"
        default: return "key_raw_\(keyCode.rawValue)"
        }
    }
    #endif
}
