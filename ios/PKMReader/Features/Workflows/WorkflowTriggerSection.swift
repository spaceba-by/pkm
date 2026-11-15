import SwiftUI

/// Trigger type and schedule fields of the workflow form
struct WorkflowTriggerSection: View {
    @Binding var draft: WorkflowDraft

    var body: some View {
        Section {
            Picker("Trigger", selection: $draft.triggerType) {
                ForEach(WorkflowTriggerType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.icon).tag(type)
                }
            }
            .accessibilityIdentifier("WorkflowTriggerPicker")

            if draft.triggerType == .schedule {
                Picker("Frequency", selection: $draft.frequency) {
                    ForEach(WorkflowScheduleFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }
                if draft.frequency == .weekly {
                    Picker("Day", selection: $draft.dayOfWeek) {
                        ForEach(WorkflowDraft.daysOfWeek, id: \.self) { day in
                            Text(day.capitalized).tag(day)
                        }
                    }
                }
                if draft.frequency != .hourly {
                    Stepper("Hour: \(String(format: "%02d", draft.hour)) UTC", value: $draft.hour, in: 0 ... 23)
                }
                Stepper("Minute: \(String(format: "%02d", draft.minute))", value: $draft.minute, in: 0 ... 59, step: 5)
            }

            if draft.triggerType == .document || draft.triggerType == .command {
                Stepper(
                    "Cooldown: \(draft.cooldownMinutes) min",
                    value: $draft.cooldownMinutes,
                    in: WorkflowDraft.cooldownRange,
                    step: 15
                )
            }
        } header: {
            Text("Trigger")
        } footer: {
            Text(footerText)
        }
    }

    private var footerText: String {
        var text = draft.triggerType.explanation
        if draft.triggerType == .schedule {
            text += " Schedules are UTC and checked every 15 minutes."
        } else if draft.triggerType == .document || draft.triggerType == .command {
            text += " The cooldown prevents repeated saves of one note from re-running the workflow."
        }
        return text
    }
}

/// Document filter fields of the workflow form
struct WorkflowFilterSection: View {
    @Binding var draft: WorkflowDraft

    var body: some View {
        Section {
            TextField("Path prefix (e.g. meetings/)", text: $draft.pathPrefix)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("WorkflowPathPrefixField")
            TextField("Tags (comma-separated)", text: $draft.tagsText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("WorkflowTagsField")
            ForEach(DocumentClassification.allCases, id: \.self) { classification in
                Toggle(
                    classification.displayName,
                    isOn: Binding(
                        get: { draft.classifications.contains(classification) },
                        set: { isOn in
                            if isOn {
                                draft.classifications.insert(classification)
                            } else {
                                draft.classifications.remove(classification)
                            }
                        }
                    )
                )
            }
            if draft.usesDocumentSet {
                Stepper(
                    "Look back \(draft.lookbackDays) day\(draft.lookbackDays == 1 ? "" : "s")",
                    value: $draft.lookbackDays,
                    in: WorkflowDraft.lookbackRange
                )
            }
        } header: {
            Text("Filter")
        } footer: {
            Text(footerText)
        }
    }

    private var footerText: String {
        if draft.usesDocumentSet {
            return "Documents modified within the lookback window that match every set condition are included, "
                + "newest first, up to 50."
        }
        return "Leave everything empty to match any document. A document needs any one of the selected tags "
            + "and one of the selected classifications."
    }
}
