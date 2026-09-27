import Foundation

/// Plans Buddy's widget animation as a list of timed frames.
///
/// Widgets can't run animations of their own. What they can do is show a list of prepared frames,
/// each at its own time, and animate the change between them. So this plans Buddy's next few
/// minutes up front: hop to a new spot, look around, blink, hop again. How lively Buddy is depends
/// on how you're doing: a thriving Buddy hops often, a low Buddy mostly shuffles, a dozing Buddy stays put.
///
/// iOS only reliably shows widget frames at least a second apart (tested: frames 0.25 s apart were
/// dropped, 1 s apart were shown). So every frame lands on a whole second: a hop spends one second in
/// the air and lands with a springy bounce, and a blink is a slow, content one-second blink.
enum BuddyChoreography {
    enum Energy {
        case lively, calm, low, dozing
    }

    struct Frame: Equatable {
        var date: Date
        var pose: BuddyPose
    }

    static func energy(health: Int, onBreak: Bool) -> Energy {
        if onBreak { return health <= 5 ? .low : .dozing }
        switch health {
        case 8...: return .lively
        case 4...7: return .calm
        default: return .low
        }
    }

    /// Frames from `start` for `duration` seconds. The same inputs always give the same frames,
    /// so a widget reload doesn't make Buddy jump somewhere random.
    static func frames(from start: Date, duration: TimeInterval, energy: Energy, startX: Double = 0.5, seed: UInt64) -> [Frame] {
        var rng = SeededGenerator(seed: seed)
        var frames = [Frame(date: start, pose: BuddyPose(x: startX))]
        var x = startX
        var t = 1.0  // first move a second after the widget appears, so tapping Buddy gets a quick reaction
        var lastSecond = 0

        /// Adds a frame on the next free whole second at or after `offset`.
        @discardableResult
        func add(_ offset: TimeInterval, _ pose: BuddyPose) -> Int {
            let second = max(lastSecond + 1, Int(offset.rounded(.up)))
            guard Double(second) < duration else { return second }
            frames.append(Frame(date: start.addingTimeInterval(Double(second)), pose: pose))
            lastSecond = second
            return second
        }

        func blink(at offset: TimeInterval) {
            // Only blink if there's room to open the eyes again before the plan ends.
            guard Double(max(lastSecond + 1, Int(offset.rounded(.up))) + 1) < duration else { return }
            let closed = add(offset, BuddyPose(x: x, eyesClosed: true))
            add(Double(closed + 1), BuddyPose(x: x))
        }

        func hop(to newX: Double, at offset: TimeInterval, height: Double) {
            let lean = newX > x ? 7.0 : -7.0
            let up = add(offset, BuddyPose(x: (x + newX) / 2, lift: height, tilt: lean))
            add(Double(up + 1), BuddyPose(x: newX, lift: 0, tilt: 0))
            x = newX
        }

        func pickSpot(minDistance: Double) -> Double {
            var candidate = Double.random(in: 0...1, using: &rng)
            for _ in 0..<8 where abs(candidate - x) < minDistance {
                candidate = Double.random(in: 0...1, using: &rng)
            }
            return candidate
        }

        // Leave a few seconds at the end so every hop lands and every blink reopens.
        while t < duration - 5 {
            switch energy {
            case .lively:
                hop(to: pickSpot(minDistance: 0.3), at: t, height: 1)
                // Sometimes a second, smaller hop right after.
                if Double.random(in: 0...1, using: &rng) < 0.35 {
                    hop(to: min(1, max(0, x + Double.random(in: -0.25...0.25, using: &rng))), at: t + 2, height: 0.55)
                }
                blink(at: t + Double.random(in: 2.2...3.5, using: &rng))
                t += Double.random(in: 4.5...7.5, using: &rng)

            case .calm:
                hop(to: pickSpot(minDistance: 0.25), at: t, height: 0.75)
                blink(at: t + Double.random(in: 3...5, using: &rng))
                t += Double.random(in: 8...13, using: &rng)

            case .low:
                // No hops: a slow shuffle a little way over, and a blink.
                let newX = min(1, max(0, x + Double.random(in: -0.2...0.2, using: &rng)))
                add(t, BuddyPose(x: newX))
                x = newX
                blink(at: t + Double.random(in: 4...7, using: &rng))
                t += Double.random(in: 14...22, using: &rng)

            case .dozing:
                // Stays put; the snoozing face does the work. An occasional small shift.
                let newX = min(1, max(0, x + Double.random(in: -0.08...0.08, using: &rng)))
                add(t, BuddyPose(x: newX))
                x = newX
                t += Double.random(in: 25...40, using: &rng)
            }
        }
        return frames
    }
}

/// A small repeatable random number generator (SplitMix64).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
