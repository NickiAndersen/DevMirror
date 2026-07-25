import XCTest
@testable import MirrorCore

final class TypesTests: XCTestCase {
    func testDefaultConfig() {
        let config = MirrorConfig.default
        XCTAssertEqual(config.sourcePath, NSHomeDirectory() + "/Developer")
        XCTAssertEqual(config.destinationPath, NSHomeDirectory() + "/Documents/DevMirror")
        XCTAssertTrue(config.includeGitFolders)
        XCTAssertEqual(config.deletionPolicy, .safeArchive)
        XCTAssertEqual(config.syncMode, .every30min)
        XCTAssertEqual(config.trashRetentionDays, 30)
        XCTAssertTrue(config.excludedNames.contains("node_modules"))
        XCTAssertTrue(config.excludedNames.contains("build"))
    }

    func testConfigCodableRoundTrip() throws {
        let config = MirrorConfig.default
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(MirrorConfig.self, from: data)
        XCTAssertEqual(decoded.sourcePath, config.sourcePath)
        XCTAssertEqual(decoded.destinationPath, config.destinationPath)
    }

    func testSyncEventCodableRoundTrip() throws {
        let event = SyncEvent(path: "src/main.swift", action: "copied")
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(SyncEvent.self, from: data)
        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.path, "src/main.swift")
        XCTAssertEqual(decoded.action, "copied")
    }

    func testDeletionPolicyAllCases() {
        let all = DeletionPolicy.allCases
        XCTAssertEqual(all.count, 3)
        XCTAssertTrue(all.contains(.safeArchive))
        XCTAssertTrue(all.contains(.exactMirror))
        XCTAssertTrue(all.contains(.never))
    }
}
