import Foundation
import Darwin.POSIX

public enum SyncError: Error {
    case copyFailed(path: String, message: String)
    case notFound(path: String)
    case typeMismatch(path: String)
}

public final class SyncEngine: @unchecked Sendable {
    private let config: MirrorConfig
    private let fileManager = FileManager.default

    public init(config: MirrorConfig) {
        self.config = config
    }

    public func copyFile(from source: URL, to destination: URL) throws {
        try ensureDestinationDirectory(for: destination)

        if isSymlink(at: source) {
            try copySymlink(from: source, to: destination)
            return
        }

        let isDir = isDirectory(at: source)
        if isDir {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            return
        }

        let tempURL = makeTempURL(near: destination)

        defer { try? fileManager.removeItem(at: tempURL) }

        let flags = copyfile_flags_t(COPYFILE_ALL | COPYFILE_CLONE)
        let result = copyfile(source.path, tempURL.path, nil, flags)

        guard result == 0 else {
            throw SyncError.copyFailed(path: source.path, message: "copyfile error \(result): \(String(cString: strerror(result)))")
        }

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.moveItem(at: tempURL, to: destination)
    }

    public func removeItem(at destination: URL) throws {
        guard fileManager.fileExists(atPath: destination.path) else { return }
        try fileManager.removeItem(at: destination)
    }

    public func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    public func fileSizeAndModificationDate(at url: URL) -> (size: Int64, mtime: Date)? {
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path) else { return nil }
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        guard let mtime = attrs[.modificationDate] as? Date else { return nil }
        return (size, mtime)
    }

    public func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return false }
        return isDir.boolValue
    }

    public func isSymlink(at url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]),
              let isSymlink = values.isSymbolicLink
        else { return false }
        return isSymlink
    }

    public func filesMatch(source: URL, dest: URL) -> Bool {
        guard let srcAttrs = fileSizeAndModificationDate(at: source),
              let destAttrs = fileSizeAndModificationDate(at: dest)
        else { return false }

        let sizeMatch = srcAttrs.size == destAttrs.size
        let mtimeMatch = abs(srcAttrs.mtime.timeIntervalSince(destAttrs.mtime)) < 1.0
        return sizeMatch && mtimeMatch
    }

    // MARK: - Private

    private func copySymlink(from source: URL, to destination: URL) throws {
        let target = try fileManager.destinationOfSymbolicLink(atPath: source.path)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.createSymbolicLink(atPath: destination.path, withDestinationPath: target)
    }

    private func ensureDestinationDirectory(for destination: URL) throws {
        let destDir = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
    }

    private func makeTempURL(near destination: URL) -> URL {
        let dir = destination.deletingLastPathComponent()
        let name = destination.lastPathComponent
        return dir.appendingPathComponent(".tmp_\(name)_\(UUID().uuidString.prefix(8))")
    }
}
