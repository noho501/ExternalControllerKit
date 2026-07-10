import Foundation

public struct Mapping: Codable, Hashable, Sendable {
    public let deviceId: String
    public let buttonId: String
    public let actionId: String

    public init(deviceId: String, buttonId: String, actionId: String) {
        self.deviceId = deviceId
        self.buttonId = buttonId
        self.actionId = actionId
    }
}
