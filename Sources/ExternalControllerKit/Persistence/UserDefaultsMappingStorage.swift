import Foundation

public struct UserDefaultsMappingStorage: MappingStorage {
    public let defaults: UserDefaults
    public let storageKey: String
    public let legacyStorageKey: String?
    public let shouldMigrateLegacyKey: Bool
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = "ExternalControllerKit.mappings",
        legacyStorageKey: String? = "external_controller_mappings",
        shouldMigrateLegacyKey: Bool = true
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.legacyStorageKey = legacyStorageKey
        self.shouldMigrateLegacyKey = shouldMigrateLegacyKey
    }

    public func loadMappings() throws -> [Mapping] {
        if let data = defaults.data(forKey: storageKey) {
            return (try? decoder.decode([Mapping].self, from: data)) ?? []
        }

        guard shouldMigrateLegacyKey, let legacyStorageKey, let data = defaults.data(forKey: legacyStorageKey) else {
            return []
        }

        let decoded = (try? decoder.decode([Mapping].self, from: data)) ?? []
        if !decoded.isEmpty {
            try? saveMappings(decoded)
        }
        defaults.removeObject(forKey: legacyStorageKey)
        return decoded
    }

    public func saveMappings(_ mappings: [Mapping]) throws {
        let data = try encoder.encode(mappings)
        defaults.set(data, forKey: storageKey)
    }

    public func clearMappings() throws {
        defaults.removeObject(forKey: storageKey)
    }
}
