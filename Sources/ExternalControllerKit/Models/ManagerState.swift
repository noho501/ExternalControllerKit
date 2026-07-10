import Foundation

public enum ManagerState: Equatable, Sendable {
    case idle
    case listening(actionId: String)
}
