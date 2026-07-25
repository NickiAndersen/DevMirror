import SwiftUI
import MirrorCore

struct MenuBarContentView: View {
    let viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading) {
            Text("DevMirror")
                .font(.headline)

            Divider()

            StatusRow(state: viewModel.syncState)

            Divider()

            Button("Open Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            Divider()

            Button("Quit DevMirror") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
    }
}

private struct StatusRow: View {
    let state: SyncState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusLabel)
                .foregroundStyle(.secondary)
        }
    }

    private var statusLabel: String {
        switch state {
        case .idle: "Idle"
        case .scanning: "Scanning..."
        case .syncing(let done, let total): "Syncing \(done)/\(total)"
        case .paused: "Paused"
        case .error(let msg): "Error: \(msg)"
        }
    }

    private var statusColor: Color {
        switch state {
        case .idle: .green
        case .scanning, .syncing: .blue
        case .paused: .yellow
        case .error: .red
        }
    }
}
