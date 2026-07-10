import Foundation

public enum DeviceKind: String, Codable, CaseIterable, Sendable {
    case gameController
    case keyboard
    case midi
}
