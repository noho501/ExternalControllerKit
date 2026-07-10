import Foundation

public struct Device: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let kind: DeviceKind
    public let batteryLevel: Double?

    public init(id: String, name: String, kind: DeviceKind, batteryLevel: Double? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.batteryLevel = batteryLevel
    }
}
