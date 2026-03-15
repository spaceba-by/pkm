import SwiftUI

@main
struct PKMSyncApp: App {
    @State private var viewModel = MenuBarViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            Image(systemName: viewModel.status.iconName)
                .symbolEffect(.rotate, isActive: viewModel.status == .syncing)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }

    init() {
        _viewModel = State(initialValue: MenuBarViewModel())
        viewModel.startScheduler()
    }
}
