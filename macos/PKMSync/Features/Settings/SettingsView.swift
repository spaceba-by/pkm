import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            vaultSection
            scheduleSection
            rcloneSection
            generalSection
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 400)
    }

    private var vaultSection: some View {
        Section("Vault") {
            HStack {
                TextField("Vault Path", text: $viewModel.configuration.vaultPath)
                    .textFieldStyle(.roundedBorder)
                Button("Browse...") {
                    viewModel.selectVaultFolder()
                }
            }
            TextField("S3 Bucket Name", text: $viewModel.configuration.bucketName)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            Picker("Sync Interval", selection: $viewModel.configuration.syncIntervalMinutes) {
                ForEach(SettingsViewModel.intervalOptions, id: \.self) { minutes in
                    Text("\(minutes) minute\(minutes == 1 ? "" : "s")").tag(minutes)
                }
            }
        }
    }

    private var rcloneSection: some View {
        Section("rclone") {
            HStack {
                TextField(
                    "rclone Path (leave empty for auto-detect)",
                    text: $viewModel.configuration.rclonePath
                )
                .textFieldStyle(.roundedBorder)
            }
            Text(viewModel.rcloneStatus)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField(
                    "Filter File Path",
                    text: $viewModel.configuration.filterFilePath
                )
                .textFieldStyle(.roundedBorder)
                Button("Browse...") {
                    viewModel.selectFilterFile()
                }
            }
        }
    }

    private var generalSection: some View {
        Section("General") {
            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { viewModel.configuration.launchAtLogin },
                    set: { viewModel.toggleLaunchAtLogin($0) }
                )
            )
        }
    }
}
