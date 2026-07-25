import XCTest
@testable import MirrorCore

final class SyncEngineTests: XCTestCase {
    var engine: SyncEngine!
    var sourceDir: URL!
    var destDir: URL!

    override func setUp() async throws {
        let tmp = FileManager.default.temporaryDirectory
        sourceDir = tmp.appendingPathComponent("SyncEngineTest_src_\(UUID().uuidString)")
        destDir = tmp.appendingPathComponent("SyncEngineTest_dst_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let config = MirrorConfig(
            sourcePath: sourceDir.path,
            destinationPath: destDir.path,
            excludedNames: [],
            includeGitFolders: true,
            deletionPolicy: .safeArchive,
            trashRetentionDays: 30
        )
        engine = SyncEngine(config: config)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: sourceDir)
        try? FileManager.default.removeItem(at: destDir)
    }

    func testCopyRegularFile() throws {
        let srcFile = sourceDir.appendingPathComponent("hello.txt")
        let destFile = destDir.appendingPathComponent("hello.txt")
        try "Hello World".write(to: srcFile, atomically: true, encoding: .utf8)

        try engine.copyFile(from: srcFile, to: destFile)

        XCTAssertTrue(engine.fileExists(at: destFile))
        let content = try String(contentsOf: destFile, encoding: .utf8)
        XCTAssertEqual(content, "Hello World")
    }

    func testCopyPreservesDirectoryStructure() throws {
        let srcFile = sourceDir.appendingPathComponent("a/b/c/deep.txt")
        let destFile = destDir.appendingPathComponent("a/b/c/deep.txt")
        try FileManager.default.createDirectory(at: srcFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "deep".write(to: srcFile, atomically: true, encoding: .utf8)

        try engine.copyFile(from: srcFile, to: destFile)

        XCTAssertTrue(engine.fileExists(at: destFile))
    }

    func testCopyOverwritesExisting() throws {
        let srcFile = sourceDir.appendingPathComponent("update.txt")
        let destFile = destDir.appendingPathComponent("update.txt")

        try "old".write(to: srcFile, atomically: true, encoding: .utf8)
        try engine.copyFile(from: srcFile, to: destFile)

        try "new version".write(to: srcFile, atomically: true, encoding: .utf8)
        try engine.copyFile(from: srcFile, to: destFile)

        let content = try String(contentsOf: destFile, encoding: .utf8)
        XCTAssertEqual(content, "new version")
    }

    func testCopySymlink() throws {
        let target = sourceDir.appendingPathComponent("real.txt")
        let symlink = sourceDir.appendingPathComponent("link.txt")
        let destLink = destDir.appendingPathComponent("link.txt")

        try "target content".write(to: target, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: target)

        try engine.copyFile(from: symlink, to: destLink)

        XCTAssertTrue(engine.fileExists(at: destLink))
        XCTAssertTrue(engine.isSymlink(at: destLink))
        let resolved = try FileManager.default.destinationOfSymbolicLink(atPath: destLink.path)
        XCTAssertEqual(resolved, target.path)
    }

    func testRemoveItem() throws {
        let file = destDir.appendingPathComponent("remove_me.txt")
        try "bye".write(to: file, atomically: true, encoding: .utf8)
        XCTAssertTrue(engine.fileExists(at: file))

        try engine.removeItem(at: file)
        XCTAssertFalse(engine.fileExists(at: file))
    }

    func testRemoveNonExistentDoesNotThrow() throws {
        let file = destDir.appendingPathComponent("never_there.txt")
        XCTAssertNoThrow(try engine.removeItem(at: file))
    }

    func testFilesMatchIdentical() throws {
        let src = sourceDir.appendingPathComponent("match.txt")
        let dst = destDir.appendingPathComponent("match.txt")

        try "same".write(to: src, atomically: true, encoding: .utf8)
        try engine.copyFile(from: src, to: dst)

        XCTAssertTrue(engine.filesMatch(source: src, dest: dst))
    }

    func testFilesMatchDifferentSize() throws {
        let src = sourceDir.appendingPathComponent("diff_size.txt")
        let dst = destDir.appendingPathComponent("diff_size.txt")

        try "abc".write(to: src, atomically: true, encoding: .utf8)
        try "abcdef".write(to: dst, atomically: true, encoding: .utf8)

        XCTAssertFalse(engine.filesMatch(source: src, dest: dst))
    }

    func testFilesMatchMissingDest() {
        let src = sourceDir.appendingPathComponent("no_dest.txt")
        try? "hi".write(to: src, atomically: true, encoding: .utf8)

        let dst = destDir.appendingPathComponent("no_dest.txt")
        XCTAssertFalse(engine.filesMatch(source: src, dest: dst))
    }

    func testIsDirectory() throws {
        let dir = sourceDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        XCTAssertTrue(engine.isDirectory(at: dir))

        let file = sourceDir.appendingPathComponent("notdir.txt")
        try "nope".write(to: file, atomically: true, encoding: .utf8)
        XCTAssertFalse(engine.isDirectory(at: file))
    }
}
