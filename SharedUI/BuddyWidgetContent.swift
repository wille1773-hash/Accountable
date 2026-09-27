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
///
/// iOS may show widget frames as still pictures, about one a second, without animating between
/// them. So every frame is drawn as a readable pose on its own, like stop-motion: in the air
/// (stretched, leaning, speed lines, a small shadow below) or just landed (squashed, dust puffs).
struct BuddyPose: Equatable {
    /// Across the available space, 0 (left) to 1 (right).
    var x = 0.5
    /// Height off the ground, 0 (standing) to 1 (top of a full hop).
    var lift = 0.0
    /// Direction of travel: -1 left, 1 right, 0 standing still. Sets the lean and speed lines.
    var dir = 0
    /// Just touched down: squash and dust puffs.
    var landing = false
    var eyesClosed = false
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

    private func tappableBuddy(size: CGFloat, eyesClosed: Bool = false) -> some View {
        wrapBuddy(AnyView(Buddy(mood: mood, size: size, health: entry.health, eyesClosed: eyesClosed)
            .frame(maxHeight: .infinity, alignment: .bottom)))
    }

    /// Buddy in `area`, standing on its bottom edge, hopping up to `hop` points high.
    private func roamingBuddy(size: CGFloat, in area: CGSize, hop: CGFloat) -> some View {
        let frameW = size * 1.3, frameH = size * 1.55
        let usable = max(0, area.width - frameW)
        let pose = entry.pose
        let cx = frameW / 2 + usable * pose.x
        let groundY = area.height - 2
        let lift = hop * pose.lift
        let airborne = pose.lift > 0.05
        let dir = CGFloat(pose.dir)

        return ZStack {
            // Shadow on the ground: smaller and fainter the higher Buddy is.
            Ellipse()
                .fill(Theme.ink.opacity(0.10 - 0.05 * pose.lift))
                .frame(width: size * (0.8 - 0.3 * pose.lift), height: size * 0.12)
                .position(x: cx, y: groundY - 1)

            if airborne && pose.dir != 0 {
                // Speed lines trailing behind.
                VStack(alignment: dir > 0 ? .trailing : .leading, spacing: size * 0.09) {
                    Capsule().frame(width: size * 0.28, height: 2.5)
                    Capsule().frame(width: size * 0.4, height: 2.5)
                    Capsule().frame(width: size * 0.22, height: 2.5)
                }
                .foregroundStyle(Theme.secondaryText.opacity(0.45))
                .position(x: cx - dir * size * 0.85, y: groundY - lift - size * 0.45)
            }

            if pose.landing {
                // Little dust puffs at the feet.
                HStack(spacing: size * 0.95) {
                    puff(size); puff(size)
                }
                .position(x: cx, y: groundY - size * 0.06)
            }

            tappableBuddy(size: size, eyesClosed: pose.eyesClosed)
                .frame(width: frameW, height: frameH)
                // Stretch on the way up, squash on landing.
                .scaleEffect(x: airborne ? 0.94 : (pose.landing ? 1.08 : 1),
                             y: airborne ? 1.07 : (pose.landing ? 0.9 : 1),
                             anchor: .bottom)
                .rotationEffect(.degrees(airborne ? Double(dir) * 9 : 0), anchor: .bottom)
                .position(x: cx, y: groundY - frameH / 2 - lift)
        }
        .frame(width: area.width, height: area.height)
        // On iOS versions that animate between widget frames, this smooths the steps.
        .animation(.spring(duration: 0.5, bounce: 0.3), value: pose)
    }

    private func puff(_ size: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            Circle().frame(width: size * 0.09, height: size * 0.09)
            Circle().frame(width: size * 0.13, height: size * 0.13)
        }
        .foregroundStyle(Theme.hairline)
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

