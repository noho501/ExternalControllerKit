import Foundation

public struct Mapping: Codable, Hashable, Sendable {
    public let deviceId: String
    public let inputId: String
    public let actionId: String

    public init(deviceId: String, inputId: String, actionId: String) {
        self.deviceId = deviceId
        self.inputId = LegacyInputIDNormalizer.normalize(inputId, for: deviceId)
        self.actionId = actionId
    }

    @available(*, deprecated, renamed: "init(deviceId:inputId:actionId:)")
    public init(deviceId: String, buttonId: String, actionId: String) {
        self.init(deviceId: deviceId, inputId: buttonId, actionId: actionId)
    }

    @available(*, deprecated, renamed: "inputId")
    public var buttonId: String {
        inputId
    }

    enum CodingKeys: String, CodingKey {
        case deviceId
        case inputId
        case buttonId
        case actionId
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let deviceId = try container.decode(String.self, forKey: .deviceId)
        let inputId = try container.decodeIfPresent(String.self, forKey: .inputId)
            ?? container.decode(String.self, forKey: .buttonId)
        let actionId = try container.decode(String.self, forKey: .actionId)
        self.init(deviceId: deviceId, inputId: inputId, actionId: actionId)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(inputId, forKey: .inputId)
        try container.encode(actionId, forKey: .actionId)
    }
}
