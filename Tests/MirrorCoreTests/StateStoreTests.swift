import XCTest
@testable import MirrorCore

final class StateStoreTests: XCTestCase {
    var store: StateStore!
    var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StateStoreTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = StateStore(appSupportDir: tempDir)
    }

    override func tearDown() async throws {
        store = nil
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSaveAndLoadConfig() throws {
        let config = MirrorConfig.default
        try store.save(config: config)
        let loaded = store.loadConfig()

        XCTAssertEqual(loaded.sourcePath, config.sourcePath)
        XCTAssertEqual(loaded.destinationPath, config.destinationPath)
    }

    func testLogAndLoadEvents() {
        store.logEvent(SyncEvent(path: "a.swift", action: "copied"))
        store.logEvent(SyncEvent(path: "b.swift", action: "deleted"))

        let events = store.loadEvents()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].path, "a.swift")
        XCTAssertEqual(events[1].path, "b.swift")
    }

    func testEventRingBuffer() {
        for i in 0..<600 {
            store.logEvent(SyncEvent(path: "file_\(i)", action: "copied"))
        }
        let events = store.loadEvents()
        XCTAssertEqual(events.count, 500)
        XCTAssertEqual(events[0].path, "file_100")
        XCTAssertEqual(events[499].path, "file_599")
    }

    func testSaveLastEventID() {
        store.saveLastEventID(12345)
        XCTAssertEqual(store.lastEventID(), 12345)

        store.saveLastEventID(67890)
        XCTAssertEqual(store.lastEventID(), 67890)
    }

    func testLastEventIDReturnsNilWhenNotSet() {
        XCTAssertNil(store.lastEventID())
    }

    func testDedupSkippedCorrupted() {
        store.logEvent(SyncEvent(path: "a.swift", action: "skipped_corrupted"))
        store.logEvent(SyncEvent(path: "a.swift", action: "skipped_corrupted"))
        store.logEvent(SyncEvent(path: "b.swift", action: "skipped_corrupted"))
        store.logEvent(SyncEvent(path: "copied.swift", action: "copied"))

        let events = store.loadEvents()
        let corrupted = events.filter { $0.action == "skipped_corrupted" }
        XCTAssertEqual(corrupted.count, 2, "Duplicate skipped_corrupted paths should be deduplicated")
        XCTAssertEqual(events.count, 3, "Should have 2 unique corrupted + 1 copied event")
    }
}
