import Foundation
import XCTest
@testable import ExternalControllerKit

final class UserDefaultsMappingStorageTests: XCTestCase {
    func testSaveLoadRoundTrip() throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let storage = UserDefaultsMappingStorage(defaults: defaults, storageKey: "mappings", legacyStorageKey: nil, shouldMigrateLegacyKey: false)
        let mappings = [Mapping(deviceId: "keyboard", inputId: "key_a", actionId: "action.jump")]

        try storage.saveMappings(mappings)

        XCTAssertEqual(try storage.loadMappings(), mappings)
    }

    func testCorruptStorageFallsBackToEmptyMappings() throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(Data("nope".utf8), forKey: "mappings")
        let storage = UserDefaultsMappingStorage(defaults: defaults, storageKey: "mappings", legacyStorageKey: nil, shouldMigrateLegacyKey: false)

        XCTAssertEqual(try storage.loadMappings(), [])
    }

    func testLegacyMigrationLoadsAndRewritesPrimaryKey() throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let data = Data(#"[{"deviceId":"midi","buttonId":"CC_7","actionId":"action.volume"}]"#.utf8)
        defaults.set(data, forKey: "external_controller_mappings")
        let storage = UserDefaultsMappingStorage(defaults: defaults, storageKey: "new_mappings", legacyStorageKey: "external_controller_mappings", shouldMigrateLegacyKey: true)

        let loaded = try storage.loadMappings()

        XCTAssertEqual(loaded, [Mapping(deviceId: "midi", inputId: "cc_7", actionId: "action.volume")])
        XCTAssertNil(defaults.object(forKey: "external_controller_mappings"))
        XCTAssertNotNil(defaults.data(forKey: "new_mappings"))
    }
}
