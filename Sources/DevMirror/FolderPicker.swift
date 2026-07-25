import SwiftUI
import AppKit

struct FolderPicker: View {
    let label: String
    @Binding var path: String
    var onChange: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: path.isEmpty ? "folder.badge.questionmark" : "folder")
                    .foregroundColor(path.isEmpty ? .secondary : .blue)
                    .font(.title3)

                if path.isEmpty {
                    Text("No folder selected")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(collapsedPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(path)
                }

                Spacer()

                Button("Choose...") {
                    pickFolder()
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
        }
    }

    private var collapsedPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = label
        panel.directoryURL = path.isEmpty
            ? FileManager.default.homeDirectoryForCurrentUser
            : URL(fileURLWithPath: path)

        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
            onChange?()
        }
    }
}
