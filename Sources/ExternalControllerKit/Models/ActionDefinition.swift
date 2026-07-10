import Foundation

public struct ActionDefinition: Codable, Hashable, Sendable {
    public let actionId: String
    public let displayTitle: String
    public let groupingKey: String?
    public let sortOrder: Int?
    public let metadata: [String: JSONValue]?

    public init(
        actionId: String,
        displayTitle: String,
        groupingKey: String? = nil,
        sortOrder: Int? = nil,
        metadata: [String: JSONValue]? = nil
    ) {
        self.actionId = actionId
        self.displayTitle = displayTitle
        self.groupingKey = groupingKey
        self.sortOrder = sortOrder
        self.metadata = metadata
    }
}
