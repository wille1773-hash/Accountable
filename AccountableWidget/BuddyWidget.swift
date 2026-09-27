import AppIntents
import SwiftUI
import WidgetKit

@main
struct AccountableWidgets: WidgetBundle {
    var body: some Widget {
        BuddyWidget()
    }
}

/// Buddy on your Home Screen.
///
/// Widgets can't run their own animations, so Buddy's movement is planned ahead as timed frames
/// (see BuddyChoreography) and iOS animates between them. Tapping Buddy starts a fresh plan with a hop.
struct BuddyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BuddyWidget", provider: BuddyProvider()) { entry in
            BuddyWidgetView(entry: entry)
                .containerBackground(Theme.background, for: .widget)
        }
        .configurationDisplayName("Buddy")
        .description("Buddy hops around your Home Screen and shows how you're doing. The better you keep your promises, the livelier Buddy gets.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Tap to hop

struct HopIntent: AppIntent {
    static var title: LocalizedStringResource = "Make Buddy hop"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        SharedStore.update { $0.widgetHops += 1 }
        return .result()
    }
}

// MARK: - Timeline

struct BuddyProvider: TimelineProvider {
    /// How long Buddy moves around after each refresh. iOS pre-draws every frame, so this stays short:
    /// 20 minutes of frames (about 1,000) took iOS so long it showed the placeholder instead.
    static let moveLength: TimeInterval = 3 * 60
    /// When to ask for a fresh plan. Between the end of the moves and this, Buddy rests in place.
    static let refreshAfter: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> BuddyEntry { .preview }

    func getSnapshot(in context: Context, completion: @escaping (BuddyEntry) -> Void) {
        completion(context.isPreview ? .preview : entry(at: .now, state: SharedStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BuddyEntry>) -> Void) {
        let now = Date.now
        let state = SharedStore.load()
        let onBreak = (state.lockout?.endsAt ?? .distantPast) > now
        var end = now.addingTimeInterval(Self.refreshAfter)
        // Replan right when a break ends, so Buddy wakes up and the countdown doesn't sit at zero.
        if onBreak, let breakEnd = state.lockout?.endsAt, breakEnd < end { end = breakEnd }

        let frames = BuddyChoreography.frames(
            from: now,
            duration: min(Self.moveLength, end.timeIntervalSince(now)),
            energy: BuddyChoreography.energy(health: state.buddyHealth, onBreak: onBreak),
            startX: Double(state.widgetHops % 5) / 4,
            seed: UInt64(now.timeIntervalSince1970) &+ UInt64(state.widgetHops)
        )
        let base = entry(at: now, state: state)
        let entries = frames.map { frame -> BuddyEntry in
            var e = base
            e.date = frame.date
            e.pose = frame.pose
            return e
        }
        completion(Timeline(entries: entries, policy: .after(end)))
    }

    private func entry(at date: Date, state: SharedState) -> BuddyEntry {
        let status: BuddyEntry.Status
        if let session = state.session {
            status = .session(requested: session.requestedMinutes, used: session.usedMinutes)
        } else if let lockout = state.lockout, lockout.endsAt > date {
            status = .cooldown(until: lockout.endsAt)
        } else {
            status = .locked
        }
        return BuddyEntry(
            date: date,
            status: status,
            health: state.buddyHealth,
            keptInARow: Progress.keptInARow(state),
            recent: Progress.recent(state).map(\.kept),
            week: Progress.week(state, now: date).map(\.minutes)
        )
    }
}

// MARK: - View

/// Maps the widget family to the shared layout, and puts Buddy behind the hop button.
struct BuddyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: BuddyEntry

    var body: some View {
        BuddyWidgetContent(entry: entry, size: family == .systemSmall ? .small : family == .systemMedium ? .medium : .large) { buddy in
            Button(intent: HopIntent()) { buddy }.buttonStyle(.plain)
        }
    }
}

#Preview(as: .systemLarge) {
    BuddyWidget()
} timeline: {
    BuddyEntry.preview
    BuddyEntry(date: .now, status: .cooldown(until: .now.addingTimeInterval(600)), health: 3, keptInARow: 0,
               recent: [true, false, false], week: [120, 90, 100, 80, 60, 70, 30])
}

extension BuddyEntry: TimelineEntry {}
