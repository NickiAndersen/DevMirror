import XCTest
@testable import MirrorCore

final class MirrorCoreTests: XCTestCase {
    func testDefaultConfig() {
        let config = MirrorConfig.default
        XCTAssertEqual(config.sourcePath, NSHomeDirectory() + "/Developer")
        XCTAssertEqual(config.destinationPath, NSHomeDirectory() + "/Documents/DeveloperBackup")
    }

    func testExclusionEngine() {
        let config = MirrorConfig.default
        let engine = ExclusionEngine(config: config)
        XCTAssertTrue(engine.isExcluded("project/node_modules/foo.js"))
        XCTAssertTrue(engine.isExcluded("build/output.txt"))
        XCTAssertTrue(engine.isExcluded(".dart_tool/package_config.json"))
        XCTAssertFalse(engine.isExcluded("project/src/main.swift"))
        XCTAssertFalse(engine.isExcluded("README.md"))
    }

    func testExclusionEngineGitFoldersIncluded() {
        var config = MirrorConfig.default
        config.includeGitFolders = true
        let engine = ExclusionEngine(config: config)
        XCTAssertFalse(engine.isExcluded("project/.git/objects/ab/cdef"))
    }

    func testExclusionEngineGitFoldersExcluded() {
        var config = MirrorConfig.default
        config.includeGitFolders = false
        let engine = ExclusionEngine(config: config)
        XCTAssertTrue(engine.isExcluded("project/.git/objects/ab/cdef"))
    }
}
