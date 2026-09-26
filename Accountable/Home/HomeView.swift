import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var askingHowLong = false
    @State private var editingApps = false

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
                Button("Apps") { editingApps = true }
            }
            .sheet(isPresented: $askingHowLong) {
                HowLongSheet()
            }
            .sheet(isPresented: $editingApps) {
                AppPickerView(isEditing: true)
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
