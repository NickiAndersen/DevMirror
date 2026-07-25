import SwiftUI
import MirrorCore

struct MenuBarContentView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DevMirror")
                .font(.headline)

            Divider()

            StatusRow(state: viewModel.syncState, isPaused: viewModel.isPaused)

            Text(viewModel.config.syncMode.displayName)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.leading, 14)

            HStack(spacing: 0) {
                Text(viewModel.sourceFolderName)
                Text(" → ")
                    .foregroundStyle(.tertiary)
                Text(viewModel.destinationFolderName)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 2) {
                if viewModel.hasError {
                    Text("Error")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(viewModel.errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .frame(minHeight: viewModel.hasError ? nil : 0)
            .clipped()

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

            Button("Open Source Folder") {
                viewModel.openSourceInFinder()
            }

            Divider()

            Button("Quit DevMirror") {
                viewModel.stopService()
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 240)
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
                .frame(maxWidth: .infinity, alignment: .leading)
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
