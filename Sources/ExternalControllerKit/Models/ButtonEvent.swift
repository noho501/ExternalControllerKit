import Foundation

public struct InputValue: Equatable, Sendable, Codable {
    public let kind: String
    public let boolValue: Bool?
    public let doubleValue: Double?
    public let integerValue: Int?

    public init(kind: String, boolValue: Bool? = nil, doubleValue: Double? = nil, integerValue: Int? = nil) {
        self.kind = kind
        self.boolValue = boolValue
        self.doubleValue = doubleValue
        self.integerValue = integerValue
    }

    public static func button(_ isPressed: Bool) -> InputValue {
        InputValue(kind: "button", boolValue: isPressed)
    }

    public static func axis(_ value: Double) -> InputValue {
        InputValue(kind: "axis", doubleValue: value)
    }

    public static func integer(_ value: Int) -> InputValue {
        InputValue(kind: "integer", integerValue: value)
    }

    public var isDigitalActivation: Bool {
        kind == "button" && boolValue == true
    }
}

public struct InputEvent: Equatable, Sendable {
    public let deviceId: String
    public let inputId: String
    public let value: InputValue

    public init(deviceId: String, inputId: String, value: InputValue) {
        self.deviceId = deviceId
        self.inputId = LegacyInputIDNormalizer.normalize(inputId, for: deviceId)
        self.value = value
    }

    @available(*, deprecated, renamed: "init(deviceId:inputId:value:)")
    public init(deviceId: String, buttonId: String, isPressed: Bool) {
        self.init(deviceId: deviceId, inputId: buttonId, value: .button(isPressed))
    }

    @available(*, deprecated, renamed: "inputId")
    public var buttonId: String {
        inputId
    }

    @available(*, deprecated, message: "Use value.boolValue instead.")
    public var isPressed: Bool {
        value.boolValue ?? false
    }
}

@available(*, deprecated, renamed: "InputEvent")
public typealias ButtonEvent = InputEvent

enum LegacyInputIDNormalizer {
    static func normalize(_ inputId: String, for deviceId: String) -> String {
        let raw = inputId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return raw }

        if raw.hasPrefix("note_") || raw.hasPrefix("cc_") || raw == "pitch_bend" || raw == "pitch_bend_value" {
            return raw
        }

        if raw.hasPrefix("key_") || raw.hasPrefix("button_") || raw.hasPrefix("dpad_") ||
            raw.hasPrefix("left_stick_") || raw.hasPrefix("right_stick_") ||
            raw == "left_trigger" || raw == "right_trigger" ||
            raw == "left_shoulder" || raw == "right_shoulder" {
            return raw
        }

        if let midiId = normalizeLegacyMIDI(raw) {
            return midiId
        }
        if let keyboardId = normalizeLegacyKeyboard(raw) {
            return keyboardId
        }
        if let gameControllerId = normalizeLegacyGameController(raw) {
            return gameControllerId
        }

        if deviceId.hasPrefix("midi_") {
            return raw.lowercased()
        }

        return raw
    }

    private static func normalizeLegacyMIDI(_ inputId: String) -> String? {
        if inputId.hasPrefix("NOTE_") {
            return "note_\(inputId.dropFirst("NOTE_".count))"
        }
        if inputId.hasPrefix("CC_") {
            return "cc_\(inputId.dropFirst("CC_".count))"
        }
        if inputId == "PITCH_BEND" {
            return "pitch_bend"
        }
        return nil
    }

    private static func normalizeLegacyKeyboard(_ inputId: String) -> String? {
        if inputId.hasPrefix("KEY_") {
            return "key_\(inputId.dropFirst("KEY_".count).lowercased())"
        }
        if inputId.hasPrefix("F"), inputId.dropFirst().allSatisfy(\.isNumber) {
            return "key_\(inputId.lowercased())"
        }
        switch inputId {
        case "DIGIT_0": return "key_0"
        case "DIGIT_1": return "key_1"
        case "DIGIT_2": return "key_2"
        case "DIGIT_3": return "key_3"
        case "DIGIT_4": return "key_4"
        case "DIGIT_5": return "key_5"
        case "DIGIT_6": return "key_6"
        case "DIGIT_7": return "key_7"
        case "DIGIT_8": return "key_8"
        case "DIGIT_9": return "key_9"
        case "SPACE": return "key_space"
        case "TAB": return "key_tab"
        case "ENTER": return "key_enter"
        case "ESCAPE": return "key_escape"
        case "BACKSPACE": return "key_backspace"
        case "ARROW_LEFT": return "key_left_arrow"
        case "ARROW_RIGHT": return "key_right_arrow"
        case "ARROW_UP": return "key_up_arrow"
        case "ARROW_DOWN": return "key_down_arrow"
        case "LEFT_SHIFT": return "key_left_shift"
        case "RIGHT_SHIFT": return "key_right_shift"
        case "LEFT_CONTROL": return "key_left_control"
        case "RIGHT_CONTROL": return "key_right_control"
        case "LEFT_OPTION": return "key_left_option"
        case "RIGHT_OPTION": return "key_right_option"
        case "LEFT_COMMAND": return "key_left_command"
        case "RIGHT_COMMAND": return "key_right_command"
        default: return nil
        }
    }

    private static func normalizeLegacyGameController(_ inputId: String) -> String? {
        switch inputId {
        case "A": return "button_a"
        case "B": return "button_b"
        case "X": return "button_x"
        case "Y": return "button_y"
        case "L1": return "left_shoulder"
        case "R1": return "right_shoulder"
        case "L2": return "left_trigger"
        case "R2": return "right_trigger"
        case "L3": return "left_stick_button"
        case "R3": return "right_stick_button"
        case "DPAD_UP": return "dpad_up"
        case "DPAD_DOWN": return "dpad_down"
        case "DPAD_LEFT": return "dpad_left"
        case "DPAD_RIGHT": return "dpad_right"
        case "LEFT_STICK_UP": return "left_stick_y"
        case "LEFT_STICK_DOWN": return "left_stick_y"
        case "LEFT_STICK_LEFT": return "left_stick_x"
        case "LEFT_STICK_RIGHT": return "left_stick_x"
        case "RIGHT_STICK_UP": return "right_stick_y"
        case "RIGHT_STICK_DOWN": return "right_stick_y"
        case "RIGHT_STICK_LEFT": return "right_stick_x"
        case "RIGHT_STICK_RIGHT": return "right_stick_x"
        default: return nil
        }
    }
}
