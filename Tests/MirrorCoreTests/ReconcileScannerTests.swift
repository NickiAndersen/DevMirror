import XCTest
@testable import MirrorCore

final class ReconcileScannerTests: XCTestCase {
    var sourceDir: URL!
    var destDir: URL!

    override func setUp() async throws {
        let tmp = FileManager.default.temporaryDirectory
        sourceDir = tmp.appendingPathComponent("ReconcileScan_src_\(UUID().uuidString)")
        destDir = tmp.appendingPathComponent("ReconcileScan_dst_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: sourceDir)
        try? FileManager.default.removeItem(at: destDir)
    }

    func makeScanner(excludeGit: Bool = true, excludedNames: Set<String> = []) -> ReconcileScanner {
        var config = MirrorConfig.default
        config.sourcePath = sourceDir.path
        config.destinationPath = destDir.path
        config.includeGitFolders = !excludeGit
        config.excludedNames = excludedNames
        let exclusionEngine = ExclusionEngine(config: config)
        let syncEngine = SyncEngine(config: config)
        return ReconcileScanner(config: config, exclusionEngine: exclusionEngine, syncEngine: syncEngine)
    }

    func testScansNewFiles() throws {
        try "file1.txt".write(to: sourceDir.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        try "file2.txt".write(to: sourceDir.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)

        let scanner = makeScanner()
        let result = try scanner.scan()

        XCTAssertEqual(result.toCopy.sorted(), ["file1.txt", "file2.txt"])
        XCTAssertTrue(result.toDelete.isEmpty)
    }

    func testScansModifiedFiles() throws {
        let src = sourceDir.appendingPathComponent("mod.txt")
        let dst = destDir.appendingPathComponent("mod.txt")

        try "v1".write(to: src, atomically: true, encoding: .utf8)
        // Copy initial version to dest
        let config = MirrorConfig.default
        var mutableConfig = config
        mutableConfig.sourcePath = sourceDir.path
        mutableConfig.destinationPath = destDir.path
        let engine = SyncEngine(config: mutableConfig)
        try engine.copyFile(from: src, to: dst)

        Thread.sleep(forTimeInterval: 1.0) // ensure mtime difference

        try "v2".write(to: src, atomically: true, encoding: .utf8)

        let scanner = makeScanner()
        let result = try scanner.scan()

        XCTAssertTrue(result.toCopy.contains("mod.txt"), "Modified file should be in toCopy list")
    }

    func testScansDeletedFiles() throws {
        let orphan = destDir.appendingPathComponent("orphan.txt")
        try "orphan".write(to: orphan, atomically: true, encoding: .utf8)

        let scanner = makeScanner()
        let result = try scanner.scan()

        XCTAssertTrue(result.toDelete.contains("orphan.txt"))
    }

    func testExcludesNodeModules() throws {
        try FileManager.default.createDirectory(at: sourceDir.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try "code".write(to: sourceDir.appendingPathComponent("node_modules/foo.js"), atomically: true, encoding: .utf8)
        let srcDir = sourceDir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try "class Foo {}".write(to: srcDir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

        let scanner = makeScanner(excludedNames: ["node_modules"])
        let result = try scanner.scan()

        XCTAssertFalse(result.toCopy.contains(where: { $0.contains("node_modules") }), "node_modules should be excluded")
        XCTAssertTrue(result.toCopy.contains(where: { $0.contains("src/main.swift") }), "src/main.swift should be included")
    }

    func testScannerExcludesTrashFolder() throws {
        let trash = destDir.appendingPathComponent("_DevMirrorTrash/old.txt")
        try FileManager.default.createDirectory(at: trash.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "old".write(to: trash, atomically: true, encoding: .utf8)

        let scanner = makeScanner()
        let result = try scanner.scan()

        XCTAssertFalse(result.toDelete.contains(where: { $0.contains("_DevMirrorTrash") }))
    }

    func testEmptyScan() throws {
        let scanner = makeScanner()
        let result = try scanner.scan()
        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(result.totalChanges, 0)
    }

    func testScannerCreatesDeepDirectories() throws {
        try FileManager.default.createDirectory(
            at: sourceDir.appendingPathComponent("a/b/c"),
            withIntermediateDirectories: true
        )
        try "hi".write(to: sourceDir.appendingPathComponent("a/b/c/deep.swift"), atomically: true, encoding: .utf8)

        let scanner = makeScanner()
        let result = try scanner.scan()

        XCTAssertTrue(result.toCopy.contains("a/b/c/deep.swift"))
    }
}
