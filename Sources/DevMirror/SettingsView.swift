import SwiftUI
import MirrorCore

struct SettingsView: View {
    let viewModel: AppViewModel

    var body: some View {
        TabView {
            GeneralPane(viewModel: viewModel)
                .tabItem { Label("General", systemImage: "gearshape") }

            ExclusionsPane(viewModel: viewModel)
                .tabItem { Label("Exclusions", systemImage: "eye.slash") }

            AboutPane()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 400)
    }
}

private struct GeneralPane: View {
    let viewModel: AppViewModel

    var body: some View {
        Form {
            Section("Folders") {
                LabeledContent("Source:") {
                    Text(viewModel.config.sourcePath)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Destination:") {
                    Text(viewModel.config.destinationPath)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Options") {
                Toggle("Include .git folders", isOn: .constant(viewModel.config.includeGitFolders))
                    .disabled(true)
                Picker("Deletion policy:", selection: .constant(viewModel.config.deletionPolicy)) {
                    ForEach(DeletionPolicy.allCases, id: \.self) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                .disabled(true)
                LabeledContent("Trash retention:") {
                    Text("\(viewModel.config.trashRetentionDays) days")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct ExclusionsPane: View {
    let viewModel: AppViewModel

    var body: some View {
        List(Array(viewModel.config.excludedNames).sorted(), id: \.self) { name in
            HStack {
                Image(systemName: "eye.slash")
                    .foregroundStyle(.secondary)
                Text(name)
            }
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension DeletionPolicy {
    var displayName: String {
        switch self {
        case .safeArchive: "Safe Archive (keep deleted files 30 days)"
        case .exactMirror: "Exact Mirror (delete immediately)"
        case .never: "Never Delete (accumulate files)"
        }
    }
}
