import SwiftUI

/// The lifetime projection from the intro, kept around so you can track your progress:
/// where you started, where your real use this week is taking you, and a "what if" slider.
struct YourTimeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var editing = false
    @State private var whatIf: Int?

    private var profile: Profile { model.state.profile }
    private var average: Int? { Progress.averageDailyMinutes(model.state) }
    /// Where the user is headed now: their real average once there is one, otherwise their starting number.
    private var nowMinutes: Int { average ?? profile.dailyMinutes }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow("Your time")
                    hero

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

    private var hero: some View {
        LifeProjectionCard(
            startMinutes: profile.dailyMinutes,
            age: profile.age,
            minutes: Binding(get: { whatIf ?? nowMinutes }, set: { whatIf = $0 }),
            caption: paceLine(value: whatIf ?? nowMinutes)
        )
    }

    private func paceLine(value: Int) -> String {
        if let average {
            let tail = value == average ? "That's where you are now." : "Drag back to \(LifeMath.format(minutes: average)) to see where you are now."
            return "This week you're averaging \(LifeMath.format(minutes: average)) a day. \(tail)"
        }
        return "Drag to see what cutting back gives you. After your first full day, this starts at your real pace."
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
