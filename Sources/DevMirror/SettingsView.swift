import SwiftUI
import MirrorCore

struct SettingsView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        TabView {
            GeneralPane(viewModel: viewModel)
                .tabItem { Label("General", systemImage: "gearshape") }

            ExclusionsPane(viewModel: viewModel)
                .tabItem { Label("Exclusions", systemImage: "eye.slash") }

            ActivityPane(viewModel: viewModel)
                .tabItem { Label("Activity", systemImage: "list.bullet") }

            AboutPane()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 520)
    }
}

private struct GeneralPane: View {
    @Bindable var viewModel: AppViewModel
    @State private var validationMessage: String?
    @State private var validationIsWarning = false
    @State private var showTrashAlert = false

    var body: some View {
        Form {
            Section("Folders") {
                FolderPicker(label: "Source:", path: $viewModel.config.sourcePath) {
                    validate()
                }

                FolderPicker(label: "Destination:", path: $viewModel.config.destinationPath) {
                    validate()
                }

                if let msg = validationMessage {
                    HStack(spacing: 6) {
                        Image(systemName: validationIsWarning ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                            .foregroundStyle(validationIsWarning ? .orange : .red)
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(validationIsWarning ? .orange : .red)
                    }
                }
            }

            Section {
                Picker("Sync frequency:", selection: $viewModel.config.syncMode) {
                    ForEach(SyncMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                Text(syncModeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Include .git folders", isOn: $viewModel.config.includeGitFolders)

                Picker("When files are deleted:", selection: $viewModel.config.deletionPolicy) {
                    ForEach(DeletionPolicy.allCases, id: \.self) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }

                if viewModel.config.deletionPolicy == .safeArchive {
                    Picker("Keep deleted files for:", selection: $viewModel.config.trashRetentionDays) {
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                        Text("60 days").tag(60)
                        Text("90 days").tag(90)
                    }

                    HStack {
                        Label("Trash: \(viewModel.trashSize)", systemImage: "trash")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if viewModel.trashFileCount > 0 {
                            Button("Empty Trash Now") {
                                showTrashAlert = true
                            }
                        }
                    }
                    .alert("Empty Trash?", isPresented: $showTrashAlert) {
                        Button("Cancel", role: .cancel) {}
                        Button("Delete \(viewModel.trashFileCount) files", role: .destructive) {
                            viewModel.emptyTrash()
                        }
                    } message: {
                        Text("This will permanently delete \(viewModel.trashFileCount) files from the trash. This cannot be undone.")
                    }
                }
            } header: {
                Text("Sync")
            }

            Section("Notifications") {
                Toggle("When sync completes", isOn: $viewModel.showNotificationOnComplete)
                Toggle("When errors occur", isOn: $viewModel.showNotificationOnError)
            }

            Section {
                Toggle("Launch at login", isOn: loginItemBinding)

                HStack(spacing: 12) {
                    Button("Apply & Restart Sync") {
                        viewModel.applyConfig()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApply)

                    Button("Revert") {
                        viewModel.config = StateStore.shared.loadConfig()
                        validationMessage = nil
                    }
                }
            } header: {
                Text("Startup")
            }
        }
        .formStyle(.grouped)
    }

    private var syncModeDescription: String {
        switch viewModel.config.syncMode {
        case .realtime:
            return "Changes are synced immediately as they happen."
        case .every5min, .every15min, .every30min, .everyHour:
            return "The source folder is scanned at the chosen interval."
        case .manual:
            return "Sync only runs when you click Sync Now in the menu bar."
        }
    }

    private var canApply: Bool {
        let result = viewModel.validatePaths(
            source: viewModel.config.sourcePath,
            destination: viewModel.config.destinationPath
        )
        return result.isValid
    }

    private func validate() {
        let result = viewModel.validatePaths(
            source: viewModel.config.sourcePath,
            destination: viewModel.config.destinationPath
        )
        if !result.isValid {
            validationMessage = result.message
            validationIsWarning = false
        } else if result.isWarning {
            validationMessage = result.message
            validationIsWarning = true
        } else {
            validationMessage = nil
            validationIsWarning = false
        }
    }

    private var loginItemBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isLoginItemEnabled },
            set: { enabled in
                if enabled {
                    viewModel.registerLoginItem()
                } else {
                    viewModel.unregisterLoginItem()
                }
            }
        )
    }
}

private struct ExclusionsPane: View {
    @Bindable var viewModel: AppViewModel
    @State private var newExclusion = ""

    var body: some View {
        VStack {
            HStack {
                TextField("Add exclusion (e.g. node_modules)", text: $newExclusion)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let trimmed = newExclusion.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    viewModel.config.excludedNames.insert(trimmed)
                    newExclusion = ""
                }
                .disabled(newExclusion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()

            List {
                ForEach(Array(viewModel.config.excludedNames).sorted(), id: \.self) { name in
                    HStack {
                        Image(systemName: "eye.slash")
                            .foregroundStyle(.secondary)
                        Text(name)
                        Spacer()
                        Button {
                            viewModel.config.excludedNames.remove(name)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct ActivityPane: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        VStack {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    viewModel.refreshEvents()
                }
            }
            .padding(.horizontal)
            .padding(.top)

            if viewModel.recentEvents.isEmpty {
                Spacer()
                Text("No activity yet")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(viewModel.recentEvents
                    .filter { $0.action != "scanning" }
                    .sorted(by: { $0.timestamp > $1.timestamp })
                    .prefix(50)
                ) { event in
                    HStack {
                        Image(systemName: event.action == "sync_complete" ? "arrow.trianglehead.clockwise" : (event.action.contains("error") ? "xmark.circle" : "checkmark.circle"))
                            .foregroundStyle(event.action.contains("error") ? .red : event.action == "sync_complete" ? .blue : .green)
                        VStack(alignment: .leading) {
                            Text(event.path)
                                .lineLimit(1)
                            Text(event.action)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(event.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.refreshEvents()
        }
    }
}

private struct AboutPane: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("DevMirror")
                .font(.title)

            Text("Version 1.0")
                .foregroundStyle(.secondary)

            Text("Real-time backup for developers.\nCode without cloud sync conflicts.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("Separates your workspace from your cloud sync, so AI tools like Cursor and Windsurf never fight with Google Drive or iCloud. Keeps your git history and uncommitted work safe in a mirrored backup.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)
                .padding(.horizontal)

            Divider()
                .frame(width: 200)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt")
                        .frame(width: 16)
                    Text("Real-time sync via FSEvents")
                }
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .frame(width: 16)
                    Text("2-second debounce, async I/O")
                }
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3.topleft.filled")
                        .frame(width: 16)
                    Text("Excludes build artifacts (17 patterns)")
                }
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .frame(width: 16)
                    Text("Safe delete with 30-day retention")
                }
                HStack(spacing: 6) {
                    Image(systemName: "arrow.trianglehead.branch")
                        .frame(width: 16)
                    Text("Mirrors .git history and uncommitted work")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            Text("© 2026 DevMirror, part of THYRING")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Link("www.thyring.com", destination: URL(string: "https://www.thyring.com")!)
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 12)
    }
}

extension DeletionPolicy {
    var displayName: String {
        switch self {
        case .safeArchive: "Safe Archive (keep deleted files)"
        case .exactMirror: "Exact Mirror (delete immediately)"
        case .never: "Never Delete (accumulate files)"
        }
    }
}
