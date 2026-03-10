import SwiftUI

/// Visual indicator bar shown on the left edge of a week row that has an associated weekly report
struct WeekReportIndicator: View {
    let hasReport: Bool
    let isUnread: Bool
    let onTap: (() -> Void)?

    @ScaledMetric private var barWidth: CGFloat = 3

    var body: some View {
        if hasReport {
            Button(action: { onTap?() }, label: {
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(barColor)
                    .frame(width: barWidth)
            })
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isUnread ? "Weekly report available, unread" : "Weekly report available")
            .accessibilityHint("Double tap to view weekly report")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("WeekReportIndicator")
        } else {
            Color.clear
                .frame(width: barWidth)
                .accessibilityHidden(true)
        }
    }

    private var barColor: Color {
        isUnread ? Color.accentColor : Color.secondary.opacity(0.4)
    }
}
