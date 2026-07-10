import Foundation

public struct ButtonEvent: Equatable, Sendable {
    public let deviceId: String
    public let buttonId: String
    public let isPressed: Bool

    public init(deviceId: String, buttonId: String, isPressed: Bool) {
        self.deviceId = deviceId
        self.buttonId = buttonId
        self.isPressed = isPressed
    }
}
