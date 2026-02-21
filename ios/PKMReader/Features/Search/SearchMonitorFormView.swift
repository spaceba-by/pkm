import SwiftUI

/// Form view for creating or editing a search monitor
struct SearchMonitorFormView: View {
    @Environment(\.dismiss)
    private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var searchTermsText = ""
    @State private var intervalHours = 6
    @State private var noveltyThreshold = 0.3
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let existingMonitor: SearchMonitor?
    private let apiClient: any APIClientProtocol
    private let onSave: ((SearchMonitorRequest) async throws -> SearchMonitor)?
    private let onUpdate: ((SearchMonitorRequest) async throws -> SearchMonitor)?

    /// Create mode initializer
    init(
        apiClient: any APIClientProtocol,
        onSave: @escaping (SearchMonitorRequest) async throws -> SearchMonitor
    ) {
        self.apiClient = apiClient
        self.existingMonitor = nil
        self.onSave = onSave
        self.onUpdate = nil
    }

    /// Edit mode initializer
    init(
        monitor: SearchMonitor,
        apiClient: any APIClientProtocol,
        onUpdate: @escaping (SearchMonitorRequest) async throws -> SearchMonitor
    ) {
        self.apiClient = apiClient
        self.existingMonitor = monitor
        self.onSave = nil
        self.onUpdate = onUpdate
        _name = State(initialValue: monitor.name)
        _description = State(initialValue: monitor.description)
        _searchTermsText = State(initialValue: monitor.searchTerms.joined(separator: ", "))
        _intervalHours = State(initialValue: monitor.intervalHours)
        _noveltyThreshold = State(initialValue: monitor.noveltyThreshold)
    }

    private var isEditing: Bool { existingMonitor != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !parseSearchTerms().isEmpty &&
        intervalHours >= 1 && intervalHours <= 168 &&
        noveltyThreshold >= 0.0 && noveltyThreshold <= 1.0
    }

    var body: some View {
        Form {
            Section("Monitor Details") {
                TextField("Name", text: $name)
                    .accessibilityIdentifier("MonitorNameField")

                TextField("Description (optional)", text: $description)
                    .accessibilityIdentifier("MonitorDescriptionField")
            }

            Section {
                TextField("Search terms (comma-separated)", text: $searchTermsText)
                    .accessibilityIdentifier("MonitorSearchTermsField")

                if !searchTermsText.isEmpty {
                    let terms = parseSearchTerms()
                    if terms.isEmpty {
                        Text("Enter at least one search term")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        FlowLayout(spacing: 4) {
                            ForEach(terms, id: \.self) { term in
                                Text(term)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            } header: {
                Text("Search Terms")
            }

            Section {
                Stepper(
                    "Every \(intervalHours) hour\(intervalHours == 1 ? "" : "s")",
                    value: $intervalHours,
                    in: 1...168
                )
                .accessibilityIdentifier("MonitorIntervalStepper")
            } header: {
                Text("Check Interval")
            } footer: {
                Text("How often to run the search (1-168 hours)")
            }

            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Novelty Threshold")
                        Spacer()
                        Text(String(format: "%.1f", noveltyThreshold))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $noveltyThreshold, in: 0...1, step: 0.1)
                        .accessibilityIdentifier("MonitorThresholdSlider")
                }
            } footer: {
                Text("Minimum novelty score to flag as significant (0.0-1.0)")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Monitor" : "New Monitor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Create") {
                    Task { await save() }
                }
                .disabled(!isValid || isSaving)
                .accessibilityIdentifier("SaveMonitorButton")
            }
        }
        .disabled(isSaving)
        .accessibilityIdentifier("SearchMonitorFormView")
    }

    private func parseSearchTerms() -> [String] {
        searchTermsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil

        let request = SearchMonitorRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            searchTerms: parseSearchTerms(),
            intervalHours: intervalHours,
            noveltyThreshold: noveltyThreshold
        )

        do {
            if isEditing {
                _ = try await onUpdate?(request)
            } else {
                _ = try await onSave?(request)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
