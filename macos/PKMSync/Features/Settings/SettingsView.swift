import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            vaultSection
            scheduleSection
            rcloneSection
            updatesSection
            generalSection
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 480)
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
                .onChange(of: viewModel.configuration.rclonePath) {
                    viewModel.checkRclone()
                }

            HStack {
                TextField(
                    "Filters File (leave empty for the managed default)",
                    text: $viewModel.configuration.filterFilePath
                )
                .textFieldStyle(.roundedBorder)
                Button("Browse...") {
                    viewModel.selectFilterFile()
                }
            }
            Text("Passed to bisync as --filters-file. Created on first sync if missing.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle(
                "Pull _agent/ from S3 after each sync",
                isOn: $viewModel.configuration.agentPullEnabled
            )
            Text("Agent output is one-way: S3 always wins, local edits are never pushed.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Force Resync") {
                    Task {
                        await viewModel.forceResync()
                    }
                }
                .disabled(viewModel.isResyncing)

                if viewModel.isResyncing {
                    ProgressView()
                        .controlSize(.small)
                }

                if let message = viewModel.resyncMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Reinitializes bisync state. Use if sync fails due to missing listing files.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var updatesSection: some View {
        Section("Updates") {
            Toggle(
                "Automatically check for updates",
                isOn: $viewModel.configuration.autoCheckForUpdates
            )
            Picker("Check interval", selection: $viewModel.configuration.updateCheckIntervalHours) {
                ForEach(SettingsViewModel.updateIntervalOptions, id: \.self) { hours in
                    Text("\(hours) hour\(hours == 1 ? "" : "s")").tag(hours)
                }
            }
            HStack {
                Button("Check Now") {
                    Task {
                        await viewModel.checkForUpdates()
                    }
                }
                .disabled(viewModel.isCheckingForUpdates)
                if viewModel.isCheckingForUpdates {
                    ProgressView()
                        .controlSize(.small)
                }
                if let message = viewModel.updateCheckMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Current version: \(viewModel.currentVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
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
