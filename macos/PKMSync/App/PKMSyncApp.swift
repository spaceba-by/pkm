import SwiftUI

@main
struct PKMSyncApp: App {
    @State private var viewModel: MenuBarViewModel

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            Image(systemName: viewModel.status.iconName)
                .symbolEffect(
                    .rotate,
                    options: .repeating,
                    isActive: viewModel.status.isSyncing
                )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }

    init() {
        let vm = MenuBarViewModel()
        _viewModel = State(initialValue: vm)
        vm.startScheduler()
        UpdateInstaller.cleanupPendingBackup()
    }
}
