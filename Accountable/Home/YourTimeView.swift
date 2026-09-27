import SwiftUI

/// The lifetime projection from the intro, kept around so you can track your progress:
/// where you started, where your real use this week is taking you, and a "what if" slider.
struct YourTimeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var editing = false
    @State private var whatIf: Int?

    private var profile: Profile { model.state.profile }
    private var start: LifeMath { LifeMath(dailyMinutes: profile.dailyMinutes, age: profile.age) }
    private var average: Int? { Progress.averageDailyMinutes(model.state) }
    /// Where the user is headed now: their real average once there is one, otherwise their starting number.
    private var nowMinutes: Int { average ?? profile.dailyMinutes }
    private var now: LifeMath { LifeMath(dailyMinutes: nowMinutes, age: profile.age) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow("Your time")
                    headline

                    Card(padding: 18) {
                        let shown = LifeMath(dailyMinutes: whatIf ?? nowMinutes, age: profile.age)
                        FutureGrid(yearsLeft: start.wholeYearsLeft,
                                   socialYears: shown.yearsAhead,
                                   wonBackYears: max(0, start.yearsAhead - shown.yearsAhead),
                                   revealed: start.wholeYearsLeft)
                        HStack(spacing: 14) {
                            legend(fill: Theme.accent, "Social media")
                            legend(fill: Theme.accentSoft, stroke: Theme.accent, "Won back")
                            legend(stroke: Theme.hairline, "Yours")
                        }
                        Text("One dot per year you have left. \"Won back\" is compared with where you started, at \(LifeMath.format(minutes: profile.dailyMinutes)) a day.")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }

                    whatIfCard

                    Card(padding: 18) {
                        Eyebrow("This week")
                        WeekChart(days: Progress.week(model.state))
                    }

                    Button(editing ? "Done editing" : "Update my starting numbers") {
                        withAnimation(Theme.spring) { editing.toggle() }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    if editing { StartingNumbersEditor() }

                    Text("How this is worked out: daily minutes as a share of every 24 hours, applied to the years the average person your age has left (\(LifeMath.source)). This week's average counts the minutes you spend in your locked apps during sessions, which is all the time you spend in them.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.accent)
    }

    @ViewBuilder
    private var headline: some View {
        let back = start.yearsAhead - now.yearsAhead
        if let average, back > 0.05 {
            VStack(alignment: .leading, spacing: 4) {
                Text("+\(LifeMath.format(years: back)) years")
                    .font(Theme.bigNumber(52))
                    .foregroundStyle(Theme.accent)
                Text("back, at this week's pace of \(LifeMath.format(minutes: average)) a day instead of \(LifeMath.format(minutes: profile.dailyMinutes)).")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if let average {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(LifeMath.format(years: now.yearsAhead)) years")
                    .font(Theme.bigNumber(52))
                    .foregroundStyle(Theme.ink)
                Text("on social media at this week's pace of \(LifeMath.format(minutes: average)) a day. Every minute you cut shows up here.")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(LifeMath.format(years: start.yearsAhead)) years")
                    .font(Theme.bigNumber(52))
                    .foregroundStyle(Theme.ink)
                Text("on social media at \(LifeMath.format(minutes: profile.dailyMinutes)) a day, where you started. After your first full day, this tracks your real pace.")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var whatIfCard: some View {
        let value = whatIf ?? nowMinutes
        let target = LifeMath(dailyMinutes: value, age: profile.age)
        return Card(padding: 18) {
            Text("What if you kept it to")
                .foregroundStyle(Theme.secondaryText)
            Text("\(LifeMath.format(minutes: value)) a day")
                .font(Theme.title(24))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
            Slider(
                value: Binding(get: { Double(value) }, set: { whatIf = Int($0) }),
                in: 0...Double(max(15, profile.dailyMinutes)),
                step: 5
            )
            .tint(Theme.accent)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("+\(LifeMath.format(years: max(0, start.yearsAhead - target.yearsAhead)))")
                    .font(Theme.bigNumber(30))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)
                Text("years back vs. where you started")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }

    private func legend(fill: Color = .clear, stroke: Color = .clear, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(fill).overlay(Circle().stroke(stroke, lineWidth: 1.5)).frame(width: 11, height: 11)
            Text(label).font(.caption).foregroundStyle(Theme.secondaryText)
        }
    }
}

/// Change the daily time and age entered in the intro.
private struct StartingNumbersEditor: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let profile = model.state.profile
        Card(padding: 18) {
            Text("Daily time when you started")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
            Text(LifeMath.format(minutes: profile.dailyMinutes))
                .font(Theme.title(22))
                .foregroundStyle(Theme.ink)
            Slider(
                value: Binding(get: { Double(profile.dailyMinutes) },
                               set: { v in model.updateProfile { $0.dailyMinutes = Int(v) } }),
                in: 15...480, step: 15
            )
            .tint(Theme.accent)
            Stepper(value: Binding(get: { profile.age }, set: { v in model.updateProfile { $0.age = v } }), in: 13...90) {
                Text("Age \(profile.age)").foregroundStyle(Theme.ink)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
