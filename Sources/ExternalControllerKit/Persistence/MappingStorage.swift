import Foundation

public protocol MappingStorage {
    func loadMappings() throws -> [Mapping]
    func saveMappings(_ mappings: [Mapping]) throws
    func clearMappings() throws
}
