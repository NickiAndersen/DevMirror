import SwiftUI
import MirrorCore

struct MenuBarContentView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DevMirror")
                .font(.headline)

            Divider()

            StatusRow(state: viewModel.syncState, isPaused: viewModel.isPaused)

            if !viewModel.config.sourcePath.isEmpty {
                Text("\(viewModel.sourceFolderName) → \(viewModel.destinationFolderName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if viewModel.hasError {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Error")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(viewModel.errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            Divider()

            Button(viewModel.isPaused ? "Resume Syncing" : "Pause Syncing") {
                viewModel.togglePause()
            }

            Button("Sync Now") {
                viewModel.runFullScan()
            }
            .disabled(viewModel.isPaused)

            Divider()

            Button("Open Backup Folder") {
                viewModel.openBackupInFinder()
            }

            Button("Open Settings...") {
                openSettings()
            }

            Divider()

            Button("Quit DevMirror") {
                viewModel.stopService()
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(minWidth: 240)
    }
}

private struct StatusRow: View {
    let state: SyncState
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusLabel)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 2)
    }

    private var statusLabel: String {
        if isPaused { return "Paused" }
        switch state {
        case .idle: return "Watching for changes"
        case .scanning: return "Scanning for changes..."
        case .syncing(let done, let total): return "Syncing \(done) of \(total)"
        case .paused: return "Paused"
        case .error: return "Error"
        }
    }

    private var statusColor: Color {
        if isPaused { return .yellow }
        switch state {
        case .idle: return .green
        case .scanning, .syncing: return .blue
        case .paused: return .yellow
        case .error: return .red
        }
    }
}
