import Foundation

public struct ExclusionEngine: Sendable {
    public let config: MirrorConfig

    public init(config: MirrorConfig) {
        self.config = config
    }

    public func isExcluded(_ relativePath: String) -> Bool {
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: true)
        for component in components {
            let name = String(component)
            if config.excludedNames.contains(name) { return true }
            if !config.includeGitFolders && name == ".git" { return true }
        }
        return false
    }
}
