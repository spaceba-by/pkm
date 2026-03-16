import SwiftUI

struct SyncLogDetailView: View {
    let timestamp: Date
    let output: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Sync Log")
                    .font(.headline)
                Text(timestamp.formatted(date: .abbreviated, time: .standard))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                }
            }
            .padding()

            Divider()

            ScrollView {
                Text(output)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 300)
    }
}
