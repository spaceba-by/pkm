import SwiftUI

/// Month/year title with left/right chevron navigation buttons
struct CalendarHeaderView: View {
    let title: String
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Previous month")
            .accessibilityIdentifier("CalendarPreviousMonth")

            Spacer()

            Text(title)
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("CalendarMonthTitle")

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Next month")
            .accessibilityIdentifier("CalendarNextMonth")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
