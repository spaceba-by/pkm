import SwiftUI

/// Individual day cell displaying the day number, today highlight, and summary dot indicator
struct CalendarDayCell: View {
    let day: CalendarDay
    let hasSummary: Bool
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
                        .foregroundStyle(dayTextColor)
                }
                .frame(width: cellSize, height: cellSize)

                Circle()
                    .fill(hasSummary ? Color.accentColor : Color.clear)
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

    private var dayTextColor: Color {
        if day.isToday {
            return .white
        }
        if !day.isCurrentMonth {
            return .secondary.opacity(0.4)
        }
        return .primary
    }

    private var accessibilityText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        let dateText = formatter.string(from: day.date)
        if day.isToday && hasSummary {
            return "\(dateText), today, daily summary available"
        } else if day.isToday {
            return "\(dateText), today"
        } else if hasSummary {
            return "\(dateText), daily summary available"
        }
        return dateText
    }
}
