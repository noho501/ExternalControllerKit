import Foundation

public enum ExternalControllerLogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

public protocol ExternalControllerLogger: Sendable {
    func log(level: ExternalControllerLogLevel, message: String)
}

public struct DisabledExternalControllerLogger: ExternalControllerLogger {
    public init() {}
    public func log(level: ExternalControllerLogLevel, message: String) {}
}

public struct ConsoleExternalControllerLogger: ExternalControllerLogger {
    public let isEnabled: Bool

    public init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    public func log(level: ExternalControllerLogLevel, message: String) {
        guard isEnabled else { return }
        print("[ExternalController][\(level.rawValue.uppercased())] \(message)")
    }
}
