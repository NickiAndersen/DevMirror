import XCTest
@testable import MirrorCore

final class SafeDeleteTests: XCTestCase {
    var safeDelete: SafeDelete!
    var destDir: URL!

    override func setUp() async throws {
        destDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SafeDeleteTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        safeDelete = SafeDelete(destinationPath: destDir.path, retentionDays: 1)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: destDir)
    }

    func testArchiveMovesFileToTrash() throws {
        let file = destDir.appendingPathComponent("sub/deleteme.txt")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "delete me".write(to: file, atomically: true, encoding: .utf8)

        try safeDelete.archive(fileAt: file)

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))

        let trashFile = destDir.appendingPathComponent("_DevMirrorTrash/sub/deleteme.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: trashFile.path))
        let content = try String(contentsOf: trashFile, encoding: .utf8)
        XCTAssertEqual(content, "delete me")
    }

    func testArchiveNonExistentFileDoesNotThrow() throws {
        let file = destDir.appendingPathComponent("nonexistent.txt")
        XCTAssertNoThrow(try safeDelete.archive(fileAt: file))
    }

    func testArchivePreservesRelativePath() throws {
        let file = destDir.appendingPathComponent("a/b/c/nested.txt")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "nested".write(to: file, atomically: true, encoding: .utf8)

        try safeDelete.archive(fileAt: file)

        let archived = destDir.appendingPathComponent("_DevMirrorTrash/a/b/c/nested.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: archived.path))
    }

    func testPurgeExpiredRemovesOldFiles() throws {
        let trashDir = destDir.appendingPathComponent("_DevMirrorTrash")
        let oldFile = trashDir.appendingPathComponent("old.txt")
        try FileManager.default.createDirectory(at: oldFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "old".write(to: oldFile, atomically: true, encoding: .utf8)

        // Set modification date to 2 days ago
        let past = Date().addingTimeInterval(-2 * 86400)
        try FileManager.default.setAttributes([.modificationDate: past], ofItemAtPath: oldFile.path)

        let newFile = trashDir.appendingPathComponent("new.txt")
        try "new".write(to: newFile, atomically: true, encoding: .utf8)

        try safeDelete.purgeExpired()

        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newFile.path))
    }
}
