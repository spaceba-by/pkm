import SwiftUI

/// Individual day cell displaying the day number, today highlight, and summary dot indicator
struct CalendarDayCell: View {
    let day: CalendarDay
    let hasSummary: Bool
    let isUnread: Bool
    let onTap: (() -> Void)?

    @ScaledMetric private var cellSize: CGFloat = 40
    @ScaledMetric private var dotSize: CGFloat = 6

    var body: some View {
        Button(action: { onTap?() }, label: {
            VStack(spacing: 2) {
                ZStack {
                    if day.isToday {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: cellSize, height: cellSize)
                    }

                    Text("\(day.dayNumber)")
                        .font(.body)
                        .fontWeight(hasSummary && isUnread ? .bold : .regular)
                        .foregroundStyle(dayTextColor)
                }
                .frame(width: cellSize, height: cellSize)

                Circle()
                    .fill(dotColor)
                    .frame(width: dotSize, height: dotSize)
            }
        })
        .disabled(onTap == nil)
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(onTap != nil ? .isButton : .isStaticText)
        .accessibilityHint(onTap != nil ? "Double tap to view daily summary" : "")
        .accessibilityIdentifier("CalendarDay_\(day.id)")
    }

    private var dotColor: Color {
        guard hasSummary else { return .clear }
        return isUnread ? Color.accentColor : Color.secondary.opacity(0.4)
    }

    private var dayTextColor: Color {
        if day.isToday {
            return .white
        }
        if !day.isCurrentMonth {
            return .secondary.opacity(0.4)
        }
        return .primary
    }

    private static let accessibilityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    private var accessibilityText: String {
        let dateText = Self.accessibilityDateFormatter.string(from: day.date)
        if day.isToday, hasSummary {
            let suffix = isUnread ? ", unread" : ""
            return "\(dateText), today, daily summary available\(suffix)"
        } else if day.isToday {
            return "\(dateText), today"
        } else if hasSummary {
            let suffix = isUnread ? ", unread" : ""
            return "\(dateText), daily summary available\(suffix)"
        }
        return dateText
    }
}
