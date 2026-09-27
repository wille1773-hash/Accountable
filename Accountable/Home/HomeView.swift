import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var askingHowLong = false
    @State private var showingSettings = false
    @State private var showingUnwind = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    StatusHero(askingHowLong: $askingHowLong)
                    UnwindCard(showing: $showingUnwind)
                    HStack(alignment: .top, spacing: 14) {
                        TodayCard()
                        StreakCard()
                    }
                    WeekStrip()
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

/// Today's promises: kept out of made.
struct TodayCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let today = model.state.days[DayKey.string(for: .now)] ?? DayStats()
        Card(padding: 18) {
            Eyebrow("Today")
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(today.kept)")
                    .font(Theme.bigNumber(40))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("/ \(today.made)")
                    .font(Theme.title(20))
                    .foregroundStyle(Theme.secondaryText)
            }
            Text(today.made == 0 ? "No promises yet" : "promises kept")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

/// Days in a row with every promise kept.
struct StreakCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let days = Streak.days(in: model.state)
        let brokeToday = (model.state.days[DayKey.string(for: .now)]?.limitsHit ?? 0) > 0
        Card(padding: 18) {
            Eyebrow("Streak")
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(days)")
                    .font(Theme.bigNumber(40))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text(days == 1 ? "day" : "days")
                    .font(Theme.title(20))
                    .foregroundStyle(Theme.secondaryText)
            }
            Text(days > 0 ? "every promise kept" : brokeToday ? "Fresh start tomorrow" : "Keep today's promises")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

/// The last seven days: a filled dot for a day with every promise kept, an open dot for a day
/// where time ran out, and a faint dot before you started.
struct WeekStrip: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        let first = model.state.firstDay.flatMap(DayKey.date(from:)).map { calendar.startOfDay(for: $0) }

        Card(padding: 18) {
            Eyebrow("This week")
            HStack {
                ForEach(days, id: \.self) { day in
                    let stats = model.state.days[DayKey.string(for: day)]
                    let started = first.map { day >= $0 } ?? false
                    VStack(spacing: 8) {
                        dot(started: started, broken: (stats?.limitsHit ?? 0) > 0)
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2)
                            .foregroundStyle(calendar.isDate(day, inSameDayAs: today) ? Theme.ink : Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func dot(started: Bool, broken: Bool) -> some View {
        if !started {
            Circle().fill(Theme.hairline).frame(width: 14, height: 14)
        } else if broken {
            Circle().stroke(Theme.accent, lineWidth: 2).frame(width: 14, height: 14)
        } else {
            Circle().fill(Theme.accent).frame(width: 14, height: 14)
        }
    }
}
