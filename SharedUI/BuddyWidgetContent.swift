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
    /// Where Buddy is and what Buddy's doing in this frame.
    var pose = BuddyPose()

    static let preview = BuddyEntry(
        date: .now, status: .locked, health: 8, keptInARow: 4,
        recent: [true, true, false, true, true, true, true],
        week: [95, 80, 60, 70, 45, 40, 25]
    )
}

/// One frame of Buddy's widget animation.
struct BuddyPose: Equatable {
    /// Across the available space, 0 (left) to 1 (right).
    var x = 0.5
    /// Height of a hop, 0 (on the ground) to 1 (top of the hop).
    var lift = 0.0
    var eyesClosed = false
    /// Slight lean in degrees, into the direction of travel.
    var tilt = 0.0
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
        wrapBuddy(AnyView(Buddy(mood: mood, size: size, health: entry.health, eyesClosed: entry.pose.eyesClosed)))
    }

    /// Buddy placed in `area`, standing on its bottom edge, hopping `hop` points high at the top of a jump.
    /// Buddy's frame is bottom-aligned, so the frame's bottom is where the feet are.
    private func roamingBuddy(size: CGFloat, in area: CGSize, hop: CGFloat) -> some View {
        let frameW = size * 1.3, frameH = size * 1.55
        let usable = max(0, area.width - frameW)
        let pose = entry.pose
        return tappableBuddy(size: size)
            .frame(width: frameW, height: frameH, alignment: .bottom)
            .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
            .position(x: frameW / 2 + usable * pose.x,
                      y: area.height - frameH / 2 - hop * pose.lift)
            // The spring between frames is what makes it read as a hop rather than a jump cut.
            .animation(.spring(response: 0.42, dampingFraction: 0.62), value: pose)
    }

    /// Small: Buddy hops around the space above the status line.
    private var small: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                roamingBuddy(size: 50, in: geo.size, hop: 18)
            }
            statusLine
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// Medium: Buddy hops around the left half, with your status on the right.
    private var medium: some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                roamingBuddy(size: 54, in: geo.size, hop: 24)
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
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.card)
                    // A soft ground line for Buddy to stand on.
                    Capsule()
                        .fill(Theme.hairline)
                        .frame(width: geo.size.width - 28, height: 3)
                        .position(x: geo.size.width / 2, y: geo.size.height - 14)
                    roamingBuddy(size: 60,
                                 in: CGSize(width: geo.size.width - 28, height: geo.size.height - 15),
                                 hop: 40)
                        .offset(x: 14)
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

