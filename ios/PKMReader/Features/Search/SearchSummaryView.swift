import SwiftUI

/// Detail view for a single search summary
struct SearchSummaryView: View {
    let summary: SearchSummary

    var body: some View {
        List {
            Section("Summary") {
                Text(summary.summary)
                    .font(.body)
            }

            if let analysis = summary.analysis, !analysis.isEmpty {
                Section("Analysis") {
                    Text(analysis)
                        .font(.body)
                }
            }

            Section("Metrics") {
                LabeledContent("Novelty Score") {
                    NoveltyIndicator(score: summary.noveltyScore)
                }

                LabeledContent("Significant Update") {
                    Image(systemName: summary.significantUpdate ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(summary.significantUpdate ? .orange : .secondary)
                }
            }

            if !summary.topics.isEmpty {
                Section("Topics") {
                    FlowLayout(spacing: 4) {
                        ForEach(summary.topics, id: \.self) { topic in
                            Text(topic)
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

            if !summary.newItems.isEmpty {
                Section("New Items") {
                    ForEach(summary.newItems, id: \.self) { item in
                        Label(item, systemImage: "plus.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    }
                }
            }

            if !summary.changedItems.isEmpty {
                Section("Changed Items") {
                    ForEach(summary.changedItems, id: \.self) { item in
                        Label(item, systemImage: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.orange)
                            .font(.subheadline)
                    }
                }
            }

            if !summary.removedItems.isEmpty {
                Section("Removed Items") {
                    ForEach(summary.removedItems, id: \.self) { item in
                        Label(item, systemImage: "minus.circle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("SearchSummaryView")
    }
}
