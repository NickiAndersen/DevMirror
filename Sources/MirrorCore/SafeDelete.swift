import Foundation

public final class SafeDelete: @unchecked Sendable {
    private let destinationPath: String
    private let retentionDays: Int
    private let fileManager = FileManager.default

    private var trashDir: URL {
        URL(fileURLWithPath: destinationPath)
            .appendingPathComponent("_DevMirrorTrash", isDirectory: true)
    }

    public init(destinationPath: String, retentionDays: Int) {
        self.destinationPath = destinationPath
        self.retentionDays = retentionDays
    }

    /// Move the destination file to the trash archive, preserving its relative path.
    public func archive(fileAt destination: URL) throws {
        guard fileManager.fileExists(atPath: destination.path) else { return }

        let destBase = URL(fileURLWithPath: destinationPath).standardizedFileURL.path
        let filePath = destination.standardizedFileURL.path
        guard filePath.hasPrefix(destBase) else { return }

        let relative = String(filePath.dropFirst(destBase.count + 1))
        let archiveURL = trashDir.appendingPathComponent(relative)

        let archiveDir = archiveURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: archiveDir, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: archiveURL.path) {
            try fileManager.removeItem(at: archiveURL)
        }

        try fileManager.moveItem(at: destination, to: archiveURL)
    }

    /// Remove archived files older than the retention period.
    public func purgeExpired() throws {
        guard fileManager.fileExists(atPath: trashDir.path) else { return }

        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86400)

        guard let enumerator = fileManager.enumerator(
            at: trashDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var urlsToDelete: [URL] = []
        for case let fileURL as URL in enumerator {
            guard let attrs = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                  let mtime = attrs.contentModificationDate
            else { continue }
            if mtime < cutoff {
                urlsToDelete.append(fileURL)
            }
        }

        for url in urlsToDelete {
            try? fileManager.removeItem(at: url)
        }

        cleanEmptyDirectories(in: trashDir)
    }

    private func cleanEmptyDirectories(in directory: URL) {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var dirs: [URL] = []
        for case let fileURL as URL in enumerator {
            if let isDir = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir {
                dirs.append(fileURL)
            }
        }

        for dir in dirs.sorted(by: { $0.path.count > $1.path.count }) {
            if let contents = try? fileManager.contentsOfDirectory(atPath: dir.path), contents.isEmpty {
                try? fileManager.removeItem(at: dir)
            }
        }
    }
}
