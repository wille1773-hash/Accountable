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
/// Widgets can't play continuous animations, so Buddy moves to a new spot (animated) each time the
/// widget refreshes, about every 15 minutes, and hops whenever you tap Buddy.
struct BuddyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BuddyWidget", provider: BuddyProvider()) { entry in
            BuddyWidgetView(entry: entry)
                .containerBackground(Theme.background, for: .widget)
        }
        .configurationDisplayName("Buddy")
        .description("Buddy hangs out on your Home Screen and shows how you're doing. Tap Buddy for a hop.")
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
    func placeholder(in context: Context) -> BuddyEntry { .preview }

    func getSnapshot(in context: Context, completion: @escaping (BuddyEntry) -> Void) {
        completion(context.isPreview ? .preview : entry(at: .now, beat: SharedStore.load().widgetHops))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BuddyEntry>) -> Void) {
        let now = Date.now
        let base = SharedStore.load().widgetHops * 7
        var dates = (0..<16).map { now.addingTimeInterval(Double($0) * 15 * 60) }
        // Refresh right when a break ends so the widget doesn't keep counting down at zero.
        if let lockout = SharedStore.load().lockout, lockout.endsAt > now, lockout.endsAt < dates.last! {
            dates.append(lockout.endsAt)
            dates.sort()
        }
        let entries = dates.enumerated().map { index, date in entry(at: date, beat: base + index) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date, beat: Int) -> BuddyEntry {
        let state = SharedStore.load()
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
            week: Progress.week(state, now: date).map(\.minutes),
            beat: beat
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
               recent: [true, false, false], week: [120, 90, 100, 80, 60, 70, 30], beat: 2)
}

extension BuddyEntry: TimelineEntry {}
