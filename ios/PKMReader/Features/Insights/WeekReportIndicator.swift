import SwiftUI

/// Visual indicator bar shown on the left edge of a week row that has an associated weekly report
struct WeekReportIndicator: View {
    let hasReport: Bool
    let onTap: (() -> Void)?

    @ScaledMetric private var barWidth: CGFloat = 3

    var body: some View {
        if hasReport {
            Button(action: { onTap?() }, label: {
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(Color.accentColor)
                    .frame(width: barWidth)
            })
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Weekly report available")
            .accessibilityHint("Double tap to view weekly report")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("WeekReportIndicator")
        } else {
            Color.clear
                .frame(width: barWidth)
                .accessibilityHidden(true)
        }
    }
}
