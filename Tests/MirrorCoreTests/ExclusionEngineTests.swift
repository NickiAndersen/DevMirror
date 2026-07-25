import XCTest
@testable import MirrorCore

final class ExclusionEngineTests: XCTestCase {
    var engine: ExclusionEngine!

    override func setUp() {
        engine = ExclusionEngine(config: .default)
    }

    func testExcludesNodeModules() {
        XCTAssertTrue(engine.isExcluded("project/node_modules/foo.js"))
        XCTAssertTrue(engine.isExcluded("node_modules/lodash/index.js"))
        XCTAssertTrue(engine.isExcluded("a/b/c/node_modules/x"))
    }

    func testExcludesBuild() {
        XCTAssertTrue(engine.isExcluded("build/output.txt"))
        XCTAssertTrue(engine.isExcluded("project/build/Debug"))
    }

    func testExcludesPods() {
        XCTAssertTrue(engine.isExcluded("ios/Pods/Alamofire/Alamofire.swift"))
    }

    func testExcludesDartTool() {
        XCTAssertTrue(engine.isExcluded(".dart_tool/package_config.json"))
        XCTAssertTrue(engine.isExcluded("project/.dart_tool/build"))
    }

    func testExcludesDSStore() {
        XCTAssertTrue(engine.isExcluded(".DS_Store"))
        XCTAssertTrue(engine.isExcluded("subdir/.DS_Store"))
    }

    func testIncludesNormalFiles() {
        XCTAssertFalse(engine.isExcluded("src/main.swift"))
        XCTAssertFalse(engine.isExcluded("README.md"))
        XCTAssertFalse(engine.isExcluded("pubspec.yaml"))
        XCTAssertFalse(engine.isExcluded("Package.swift"))
    }

    func testIncludesGitByDefault() {
        XCTAssertFalse(engine.isExcluded(".git/config"))
        XCTAssertFalse(engine.isExcluded("project/.git/objects/ab/cdef"))
    }

    func testExcludesGitWhenDisabled() {
        var config = MirrorConfig.default
        config.includeGitFolders = false
        engine = ExclusionEngine(config: config)

        XCTAssertTrue(engine.isExcluded(".git/config"))
        XCTAssertTrue(engine.isExcluded("project/.git/HEAD"))
    }

    func testEmptyPath() {
        XCTAssertFalse(engine.isExcluded(""))
    }

    func testTopLevelExclusion() {
        XCTAssertTrue(engine.isExcluded("DerivedData"))
        XCTAssertTrue(engine.isExcluded("DerivedData/ModuleCache/Session.modulevalidation"))
    }
}
