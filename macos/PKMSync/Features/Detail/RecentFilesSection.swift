import SwiftUI

struct RecentFilesSection: View {
    let files: [RecentFile]
    let onOpen: (RecentFile) -> Void

    var body: some View {
        if files.isEmpty {
            ContentUnavailableView(
                "No Recent Files",
                systemImage: "doc.text",
                description: Text("Recently modified markdown files will appear here.")
            )
        } else {
            List(files) { file in
                Button {
                    onOpen(file)
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        VStack(alignment: .leading) {
                            Text(file.name)
                                .font(.body)
                            Text(file.modified, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
