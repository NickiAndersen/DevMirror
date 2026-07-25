import SwiftUI
import MirrorCore

@main
struct DevMirrorApp: App {
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra("DevMirror", systemImage: "externaldrive") {
            MenuBarContentView(viewModel: viewModel)
        }

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
