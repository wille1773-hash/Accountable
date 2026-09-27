import SwiftUI

/// Everything a Buddy widget shows. Shared with the app so the layouts can be previewed there.
struct BuddyEntry {
    enum Status {
        case locked
        case session(requested: Int, used: Int)
        case cooldown(until: Date)
    }

    var date: Date
    var status: Status
    var health: Int
    var keptInARow: Int
    var recent: [Bool]
    var week: [Int]
    /// Changes on every refresh and every tap; decides where Buddy is standing.
    var beat: Int

    static let preview = BuddyEntry(
        date: .now, status: .locked, health: 8, keptInARow: 4,
        recent: [true, true, false, true, true, true, true],
        week: [95, 80, 60, 70, 45, 40, 25], beat: 1
    )
}

enum WidgetSizeClass { case small, medium, large }

/// The widget layouts. `wrapBuddy` lets the widget put Buddy inside its tap-to-hop button.
struct BuddyWidgetContent: View {
    var entry: BuddyEntry
    var size: WidgetSizeClass
    var wrapBuddy: (AnyView) -> AnyView

    init<Wrapped: View>(entry: BuddyEntry, size: WidgetSizeClass, wrapBuddy: @escaping (AnyView) -> Wrapped) {
        self.entry = entry
        self.size = size
        self.wrapBuddy = { AnyView(wrapBuddy($0)) }
    }

    init(entry: BuddyEntry, size: WidgetSizeClass) {
        self.init(entry: entry, size: size) { $0 }
    }

    var body: some View {
        switch size {
        case .small: small
        case .medium: medium
        case .large: large
        }
    }

    private var mood: Buddy.Mood {
        switch entry.status {
        case .session: entry.health >= 4 ? .happy : .neutral
        case .cooldown: entry.health <= 5 ? .sad : .sleepy
        case .locked: BuddyStatus(health: entry.health).restingMood
        }
    }

    private func tappableBuddy(size: CGFloat) -> some View {
        wrapBuddy(AnyView(Buddy(mood: mood, size: size, health: entry.health)))
    }

    /// Small: Buddy hops in place.
    private var small: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            tappableBuddy(size: 58)
                .offset(y: entry.beat.isMultiple(of: 2) ? 0 : -10)
                .rotationEffect(.degrees(entry.beat % 3 == 0 ? -4 : entry.beat % 3 == 1 ? 4 : 0))
                .animation(.spring(response: 0.45, dampingFraction: 0.45), value: entry.beat)
            Spacer(minLength: 0)
            statusLine
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// Medium: Buddy wanders side to side, with your status.
    private var medium: some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                let spots: [CGFloat] = [0.3, 0.7, 0.5, 0.2, 0.8]
                tappableBuddy(size: 56)
                    .position(x: geo.size.width * spots[entry.beat % spots.count],
                              y: geo.size.height * (entry.beat.isMultiple(of: 2) ? 0.62 : 0.52))
                    .animation(.spring(response: 0.6, dampingFraction: 0.55), value: entry.beat)
            }
            VStack(alignment: .leading, spacing: 6) {
                statusLine.font(.subheadline.weight(.semibold))
                keptInARowLine
                RecentDots(recent: entry.recent, size: 9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Large: a little field Buddy roams around, then your progress.
    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                // Horizontal spot, and how high Buddy is hopping (0 = standing on the ground).
                let spots: [(x: CGFloat, lift: CGFloat)] = [
                    (0.22, 0), (0.7, 22), (0.5, 0), (0.82, 0), (0.15, 16), (0.6, 0),
                ]
                let spot = spots[entry.beat % spots.count]
                let groundY = geo.size.height * 0.86
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.card)
                    // A soft ground line for Buddy to stand on.
                    Capsule()
                        .fill(Theme.hairline)
                        .frame(height: 3)
                        .padding(.horizontal, 14)
                        .position(x: geo.size.width / 2, y: groundY)
                    // Buddy's frame is bottom-aligned, so its bottom edge is where the feet are.
                    tappableBuddy(size: 60)
                        .frame(height: 93, alignment: .bottom)
                        .position(x: geo.size.width * spot.x, y: groundY - 93 / 2 - spot.lift)
                        .animation(.spring(response: 0.7, dampingFraction: 0.55), value: entry.beat)
                }
            }
            .frame(height: 150)

            HStack(alignment: .firstTextBaseline) {
                statusLine.font(.headline)
                Spacer()
                keptInARowLine
            }
            RecentDots(recent: entry.recent, size: 12)
            VStack(alignment: .leading, spacing: 4) {
                Text("Minutes a day, this week")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                WeekBars(minutes: entry.week)
                    .frame(height: 40)
            }
            Text(BuddyStatus(health: entry.health).line)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch entry.status {
        case .locked:
            Label("Locked", systemImage: "lock.fill").foregroundStyle(Theme.ink)
        case .session(let requested, let used):
            Text("\(max(0, requested - used)) min left").foregroundStyle(Theme.accent)
        case .cooldown(let until):
            HStack(spacing: 4) {
                Text("Back in").foregroundStyle(Theme.secondaryText)
                Text(timerInterval: Date.now...until, countsDown: true)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }
        }
    }

    private var keptInARowLine: some View {
        Text(entry.keptInARow == 1 ? "1 kept in a row" : "\(entry.keptInARow) kept in a row")
            .font(.caption)
            .foregroundStyle(Theme.secondaryText)
    }
}

/// Minutes per day for the last week, today on the right.
struct WeekBars: View {
    var minutes: [Int]

    var body: some View {
        let top = max(minutes.max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(minutes.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 3)
                    .fill(index == minutes.count - 1 ? Theme.accent : Theme.accentSoft)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(3, CGFloat(value) / CGFloat(top) * 40))
            }
        }
    }
}

