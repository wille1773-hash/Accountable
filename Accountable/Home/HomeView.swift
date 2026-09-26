import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var askingHowLong = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    StatusCard(askingHowLong: $askingHowLong)
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Accountable")
            .toolbar {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
            .sheet(isPresented: $askingHowLong) {
                HowLongSheet()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

/// The big card at the top: what's happening right now.
struct StatusCard: View {
    @EnvironmentObject private var model: AppModel
    @Binding var askingHowLong: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Card {
                if let session = model.state.session {
                    sessionView(session, now: context.date)
                } else if let lockout = model.state.lockout, lockout.endsAt > context.date {
                    cooldownView(lockout, now: context.date)
                } else {
                    lockedView
                }
            }
        }
    }

    private func sessionView(_ session: ActiveSession, now: Date) -> some View {
        let left = max(0, session.requestedMinutes - session.usedMinutes)
        return VStack(alignment: .leading, spacing: 8) {
            Label("Unlocked", systemImage: "lock.open")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(left)")
                    .font(Theme.bigNumber(72))
                Text("min left")
                    .font(.title3)
                    .foregroundStyle(Theme.secondaryText)
            }
            Text("of the \(session.requestedMinutes) you asked for. Only time in your apps counts.")
                .foregroundStyle(Theme.secondaryText)
            Text("Session ends by \(session.windowEnd.formatted(date: .omitted, time: .shortened)) either way.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            Button("I'm done") { model.endSessionEarly() }
                .buttonStyle(.primary)
                .padding(.top, 8)
        }
    }

    private func cooldownView(_ lockout: Lockout, now: Date) -> some View {
        let remaining = Int(lockout.endsAt.timeIntervalSince(now).rounded(.up))
        return VStack(alignment: .leading, spacing: 8) {
            Label("Taking a breather", systemImage: "hourglass")
                .font(.headline)
            Text(Self.clock(remaining))
                .font(Theme.bigNumber(72))
            Text("You used the time you asked for. You can start again at \(lockout.endsAt.formatted(date: .omitted, time: .shortened)).")
                .foregroundStyle(Theme.secondaryText)
            if CooldownPolicy.isEscalating(model.state) {
                Text("Hit the limit again today and the next break is \(CooldownPolicy.nextMinutes(state: model.state, now: now)) min.")
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

    private var lockedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Locked", systemImage: "lock")
                .font(.headline)
            Text("Holding you to \(model.state.selection.summary).")
                .foregroundStyle(Theme.secondaryText)
            Button("How long do you want?") { askingHowLong = true }
                .buttonStyle(.primary)
                .padding(.top, 8)
        }
    }
}
