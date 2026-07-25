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
        .frame(width: 520, height: 440)
    }
}

private struct GeneralPane: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        Form {
            Section("Folders") {
                LabeledContent("Source:") {
                    TextField("~/Developer", text: $viewModel.config.sourcePath)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Destination:") {
                    TextField("~/Documents/DeveloperBackup", text: $viewModel.config.destinationPath)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section("Sync Options") {
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
                }
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: loginItemBinding)

                HStack {
                    Button("Apply & Restart Sync") {
                        viewModel.applyConfig()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Revert") {
                        viewModel.config = StateStore.shared.loadConfig()
                    }
                }
            }
        }
        .formStyle(.grouped)
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
                List(viewModel.recentEvents.sorted(by: { $0.timestamp > $1.timestamp }).prefix(50)) { event in
                    HStack {
                        Image(systemName: event.action.contains("error") ? "xmark.circle" : "checkmark.circle")
                            .foregroundStyle(event.action.contains("error") ? .red : .green)
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

            Text("Automatically mirrors ~/Developer to ~/Documents/DeveloperBackup")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("Changes are synced in real time. The backup folder is monitored by Google Drive for cloud backup.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
