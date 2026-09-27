import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var askingHowLong = false
    @State private var showingSettings = false
    @State private var showingUnwind = false
    @State private var showingYourTime = false
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    StatusHero(askingHowLong: $askingHowLong)
                    UnwindCard(showing: $showingUnwind)
                    HStack(alignment: .top, spacing: 14) {
                        InARowCard()
                        RecentCard()
                    }
                    YourTimeCard(showing: $showingYourTime)
                    if DemoMode.isOn { demoNote }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .animation(Theme.spring, value: model.state.session)
                .animation(Theme.spring, value: model.state.lockout)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $askingHowLong) {
                HowLongSheet()
                    .presentationDetents([.fraction(0.72), .large])
                    .presentationCornerRadius(28)
                    .presentationBackground(Theme.background)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingUnwind) {
                UnwindView()
            }
            .sheet(isPresented: $showingYourTime) {
                YourTimeView()
            }
            .overlay(alignment: .top) {
                if let toast {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Theme.accent, in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            // A kept promise lifts Buddy's mood: say so, so the recovery is visible.
            .onChange(of: model.state.buddyHealth) { old, new in
                guard new != old else { return }
                let message = new > old ? "Promise kept. Buddy perked up." : "Time ran out. Buddy's a bit down."
                withAnimation(Theme.spring) { toast = message }
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation(Theme.spring) { if toast == message { toast = nil } }
                }
            }
            .sensoryFeedback(trigger: model.state.buddyHealth) { old, new in
                new > old ? .success : .warning
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                Text("Accountable")
                    .font(Theme.title(26))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Theme.card, in: Circle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var demoNote: some View {
        Text("Simulator demo: nothing is really locked, and time runs 30× faster so you can see sessions and breaks play out.")
            .font(.footnote)
            .foregroundStyle(Theme.secondaryText)
            .padding(.top, 4)
    }
}

// MARK: - Status

/// The big card at the top: locked, in a session, or on a break.
struct StatusHero: View {
    @EnvironmentObject private var model: AppModel
    @Binding var askingHowLong: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Group {
                if let session = model.state.session {
                    SessionStatus(session: session)
                } else if let lockout = model.state.lockout, lockout.endsAt > context.date {
                    CooldownStatus(lockout: lockout, now: context.date)
                } else {
                    LockedStatus(askingHowLong: $askingHowLong)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct LockedStatus: View {
    @EnvironmentObject private var model: AppModel
    @Binding var askingHowLong: Bool

    private var status: BuddyStatus { BuddyStatus(health: model.state.buddyHealth) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Locked", systemImage: "lock.fill")
                        .font(Theme.label)
                        .foregroundStyle(Theme.secondaryText)
                    Text("Your apps are resting.")
                        .font(Theme.display(28))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                Buddy(mood: status.restingMood, size: 64, health: status.health)
            }
            Text(status.line)
                .foregroundStyle(Theme.secondaryText)
            MoodMeter(health: status.health)
            Button("How long do you want?") { askingHowLong = true }
                .buttonStyle(.accent)
                .padding(.top, 4)
        }
    }
}

private struct SessionStatus: View {
    @EnvironmentObject private var model: AppModel
    var session: ActiveSession

    private var left: Int { max(0, session.requestedMinutes - session.usedMinutes) }
    private var progress: Double {
        guard session.requestedMinutes > 0 else { return 0 }
        return Double(session.usedMinutes) / Double(session.requestedMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    Circle().stroke(Theme.hairline, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: 1 - progress)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: progress)
                    VStack(spacing: 0) {
                        Text("\(left)")
                            .font(Theme.bigNumber(46))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText(countsDown: true))
                            .animation(.snappy, value: left)
                        Text("min left")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .frame(width: 132, height: 132)

                VStack(alignment: .leading, spacing: 6) {
                    Buddy(mood: model.state.buddyHealth >= 4 ? .happy : .neutral, size: 40, health: model.state.buddyHealth)
                        .frame(height: 60, alignment: .bottom)
                    Label("Unlocked", systemImage: "lock.open.fill")
                        .font(Theme.label)
                        .foregroundStyle(Theme.accent)
                    Text("You said \(session.requestedMinutes).")
                        .font(Theme.title(22))
                        .foregroundStyle(Theme.ink)
                    Text("Only time in your apps counts.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            Button("I'm done") { model.endSessionEarly() }
                .buttonStyle(.primary)
        }
    }
}

private struct CooldownStatus: View {
    @EnvironmentObject private var model: AppModel
    var lockout: Lockout
    var now: Date

    var body: some View {
        let remaining = Int(DemoMode.displaySeconds(lockout.endsAt.timeIntervalSince(now)).rounded(.up))
        let backAt = DemoMode.isOn ? now.addingTimeInterval(Double(remaining)) : lockout.endsAt
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Taking a breather", systemImage: "hourglass")
                        .font(Theme.label)
                        .foregroundStyle(Theme.secondaryText)
                    Text(Self.clock(remaining))
                        .font(Theme.bigNumber(64))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: remaining)
                }
                Spacer()
                let health = model.state.buddyHealth
                Buddy(mood: health <= 5 ? .sad : .sleepy, size: 64, health: health)
            }
            Text("That was the time you asked for. Back at \(backAt.formatted(date: .omitted, time: .shortened)).")
                .foregroundStyle(Theme.secondaryText)
            Text(BuddyStatus(health: model.state.buddyHealth).line)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            if CooldownPolicy.isEscalating(model.state) {
                Text("Run out again today and the next break is \(CooldownPolicy.nextMinutes(state: model.state, now: now)) min.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    /// 425 -> "7:05", 3725 -> "1:02:05"
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
}

// MARK: - Unwind

/// Shortcut to the calm tools. Worded for the moment: a pull to scroll, or waiting out a break.
struct UnwindCard: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showing: Bool

    var body: some View {
        let onBreak = (model.state.lockout?.endsAt ?? .distantPast) > .now
        Button { showing = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "wind")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(Theme.accentSoft, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(onBreak ? "While you wait" : "Feeling the pull?")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Breathe, ground yourself, or find something else to do.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stats

/// Kept promises since the last one that ran out. Always winnable back: one kept promise starts a new run.
struct InARowCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let count = Progress.keptInARow(model.state)
        let hasHistory = !model.state.recentPromises.isEmpty
        Card(padding: 18) {
            Eyebrow("In a row")
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(count)")
                    .font(Theme.bigNumber(40))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: count)
                Text("kept")
                    .font(Theme.title(20))
                    .foregroundStyle(Theme.secondaryText)
            }
            Text(!hasHistory ? "Your first promise starts it" : count == 0 ? "Keep the next one to start again" : "Keep it going")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

/// The last ten promises. Old ones roll off, so a good run replaces a bad stretch.
struct RecentCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let recent = Progress.recent(model.state)
        let kept = recent.filter(\.kept).count
        Card(padding: 18) {
            Eyebrow("Recent")
            if recent.isEmpty {
                Text("—").font(Theme.bigNumber(40)).foregroundStyle(Theme.hairline)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(kept)")
                        .font(Theme.bigNumber(40))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("of \(recent.count)")
                        .font(Theme.title(20))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            RecentDots(recent: recent.map(\.kept), size: 9)
                .frame(height: 16, alignment: .leading)
        }
    }
}

/// Buddy's mood as ten small segments. Watching it fill back up is the point.
struct MoodMeter: View {
    var health: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<10, id: \.self) { i in
                Capsule()
                    .fill(i < health ? Theme.accent : Theme.hairline)
                    .frame(height: 5)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: health)
        .accessibilityElement()
        .accessibilityLabel("Buddy's mood, \(health) out of 10")
    }
}

/// This week's minutes, and a way into the full "Your time" view.
struct YourTimeCard: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showing: Bool

    var body: some View {
        let week = Progress.week(model.state)
        Button { showing = true } label: {
            Card(padding: 18) {
                HStack {
                    Eyebrow("This week")
                    Spacer()
                    Text("Your time")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                WeekChart(days: week)
                Text("Minutes on your apps each day. Tap to see what it adds up to over a lifetime.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
    }
}

struct WeekChart: View {
    var days: [Progress.DayMinutes]

    var body: some View {
        let top = max(days.map(\.minutes).max() ?? 0, 1)
        let calendar = Calendar.current
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(days) { day in
                let isToday = calendar.isDateInToday(day.date)
                VStack(spacing: 6) {
                    Text(day.minutes > 0 ? "\(day.minutes)" : "")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.secondaryText)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isToday ? Theme.accent : Theme.accentSoft)
                        .frame(height: max(4, CGFloat(day.minutes) / CGFloat(top) * 56))
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .foregroundStyle(isToday ? Theme.ink : Theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 96, alignment: .bottom)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: days.map(\.minutes))
    }
}
