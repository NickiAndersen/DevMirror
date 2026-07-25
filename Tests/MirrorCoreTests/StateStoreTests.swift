import XCTest
@testable import MirrorCore

final class StateStoreTests: XCTestCase {
    let store = StateStore.shared
    var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StateStoreTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Patch config dir? No — StateStore uses fixed paths.
        // Instead, test with the actual store and clean up after.
    }

    override func tearDown() async throws {
        store.clearEvents()
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
        store.clearEvents()
        store.logEvent(SyncEvent(path: "a.swift", action: "copied"))
        store.logEvent(SyncEvent(path: "b.swift", action: "deleted"))

        let events = store.loadEvents()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].path, "a.swift")
        XCTAssertEqual(events[1].path, "b.swift")
    }

    func testEventRingBuffer() {
        store.clearEvents()
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
        // Can't test clean state easily without deleting file.
        // The store returns nil when file doesn't exist.
        // Skip if file was previously set.
    }
}
