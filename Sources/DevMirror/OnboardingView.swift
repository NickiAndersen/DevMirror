import SwiftUI

struct OnboardingView: View {
    @Bindable var viewModel: AppViewModel
    let onComplete: () -> Void

    @State private var sourcePath = ""
    @State private var destPath = ""
    @State private var useRecommendedExclusions = true
    @State private var validationMessage: String?
    @State private var validationIsWarning = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "externaldrive")
                    .font(.system(size: 42))
                    .foregroundStyle(.blue)

                Text("Welcome to DevMirror")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Keep any folder backed up automatically.\nChanges are mirrored in real time.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                FolderPicker(label: "Folder to back up (source):", path: $sourcePath) {
                    validate()
                }

                FolderPicker(label: "Where to save the backup (destination):", path: $destPath) {
                    validate()
                }

                if let msg = validationMessage {
                    HStack(spacing: 6) {
                        Image(systemName: validationIsWarning ? "exclamationmark.triangle" : "xmark.circle")
                            .foregroundStyle(validationIsWarning ? .orange : .red)
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(validationIsWarning ? .orange : .red)
                    }
                    .padding(.horizontal, 4)
                }

                Toggle(isOn: $useRecommendedExclusions) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Exclude common build/cache folders")
                        Text("node_modules, build, Pods, .dart_tool, .git, etc.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            HStack {
                Button("Quit") {
                    NSApp.terminate(nil)
                }

                Spacer()

                Button("Start Syncing") {
                    complete()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canStart)
            }
        }
        .padding(28)
        .frame(width: 520, height: 420)
        .onAppear {
            sourcePath = viewModel.config.sourcePath
            destPath = viewModel.config.destinationPath
            validate()
        }
    }

    private var canStart: Bool {
        !sourcePath.isEmpty && !destPath.isEmpty && (validationMessage == nil || validationIsWarning)
    }

    private func validate() {
        guard !sourcePath.isEmpty, !destPath.isEmpty else {
            validationMessage = nil
            return
        }

        let srcURL = URL(fileURLWithPath: sourcePath).standardizedFileURL
        let dstURL = URL(fileURLWithPath: destPath).standardizedFileURL

        // Can't be same folder
        if srcURL.path == dstURL.path {
            validationMessage = "Source and destination cannot be the same folder."
            validationIsWarning = false
            return
        }

        // Destination can't be inside source
        if dstURL.path.hasPrefix(srcURL.path + "/") {
            validationMessage = "Destination is inside the source folder. This would cause infinite looping."
            validationIsWarning = false
            return
        }

        // Source can't be inside destination
        if srcURL.path.hasPrefix(dstURL.path + "/") {
            validationMessage = "Source is inside the destination folder. Choose a destination outside the source."
            validationIsWarning = false
            return
        }

        // Source must exist
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: srcURL.path, isDirectory: &isDir) || !isDir.boolValue {
            validationMessage = "Source folder does not exist."
            validationIsWarning = false
            return
        }

        // Cloud folder warning
        if isCloudSyncedFolder(dstURL) {
            validationMessage = "This folder appears to be synced by iCloud or Dropbox. For best results, use a folder synced by Google Drive or a local folder."
            validationIsWarning = true
            return
        }

        // Valid
        validationMessage = nil
        validationIsWarning = false
    }

    private func isCloudSyncedFolder(_ url: URL) -> Bool {
        let path = url.path
        return path.contains("Library/Mobile Documents") ||
               path.contains("/Dropbox/") ||
               path.contains("/OneDrive/")
    }

    private func complete() {
        viewModel.config.sourcePath = sourcePath
        viewModel.config.destinationPath = destPath
        if !useRecommendedExclusions {
            viewModel.config.excludedNames = []
        }
        onComplete()
    }
}
