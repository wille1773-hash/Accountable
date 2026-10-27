import SwiftUI

/// The interactive lifetime card used in the intro and on Your time: a big number for the years
/// spent on social media at the chosen daily time, the years won back compared with where you
/// started, a slider, and one dot per year left.
struct LifeProjectionCard: View {
    /// Daily minutes the user started with (the baseline for "won back").
    var startMinutes: Int
    var age: Int
    /// The daily time being tried out with the slider.
    @Binding var minutes: Int
    /// Small line under the slider.
    var caption: String

    private var start: LifeMath { LifeMath(dailyMinutes: startMinutes, age: age) }
    private var target: LifeMath { LifeMath(dailyMinutes: minutes, age: age) }
    private var back: Double { max(0, start.yearsAhead - target.yearsAhead) }
    @State private var revealed = 0

    var body: some View {
        Card(padding: 20) {
            Text("At \(LifeMath.format(minutes: minutes)) a day")
                .font(.headline)
                .foregroundStyle(Theme.secondaryText)
                .contentTransition(.numericText())
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(LifeMath.format(years: target.yearsAhead))
                    .font(Theme.bigNumber(64))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("years of your life\non social media")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }

            // The payoff, front and center.
            HStack(spacing: 10) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 26))
                VStack(alignment: .leading, spacing: 0) {
                    Text("+\(LifeMath.format(years: back)) years back")
                        .font(Theme.title(24))
                        .contentTransition(.numericText())
                    Text(back > 0.05
                         ? "compared with \(LifeMath.format(minutes: startMinutes)) a day"
                         : "drag the slider to cut back")
                        .font(.caption)
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(back > 0.05 ? Color.white : Theme.secondaryText)
            .padding(14)
            .background(back > 0.05 ? Theme.accent : Theme.hairline,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.vertical, 4)

            Slider(
                value: Binding(get: { Double(minutes) }, set: { minutes = Int($0) }),
                in: 0...Double(max(15, startMinutes)),
                step: 5
            )
            .tint(Theme.accent)
            Text(caption)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            FutureGrid(yearsLeft: start.wholeYearsLeft,
                       socialYears: target.yearsAhead,
                       wonBackYears: back,
                       revealed: revealed)
                .padding(.top, 6)
            HStack(spacing: 14) {
                legend(fill: Theme.accent, "Social media")
                legend(fill: Theme.accentSoft, stroke: Theme.accent, "Won back")
                legend(stroke: Theme.hairline, "Yours")
            }
        }
        .animation(.snappy, value: minutes)
        .sensoryFeedback(.selection, trigger: minutes)
        .task {
            // Fill the grid a few dots at a time the first time it appears.
            guard revealed == 0 else { return }
            for step in 1...max(1, start.wholeYearsLeft) {
                try? await Task.sleep(for: .milliseconds(15))
                revealed = step
            }
        }
    }

    private func legend(fill: Color = .clear, stroke: Color = .clear, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(fill).overlay(Circle().stroke(stroke, lineWidth: 1.5)).frame(width: 11, height: 11)
            Text(label).font(.caption).foregroundStyle(Theme.secondaryText)
        }
    }
}
