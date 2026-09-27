import Foundation

/// Plans Buddy's widget animation as a list of timed frames.
///
/// Widgets can't run animations of their own. What they can do is show a list of prepared frames,
/// each at its own time, and animate the change between them. So this plans Buddy's next few
/// minutes up front: hop to a new spot, look around, blink, hop again. How lively Buddy is depends
/// on how you're doing: a thriving Buddy hops often, a low Buddy mostly shuffles, a dozing Buddy stays put.
///
/// Tested on the Home Screen: iOS shows widget frames about once a second (closer ones are dropped)
/// and may not animate between them at all. So Buddy moves like stop-motion: small hops, one pose
/// per second (in the air, then landed), so each change is a short, readable step rather than a jump
/// across the widget.
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
        var pose = BuddyPose(x: startX)
        var frames = [Frame(date: start, pose: pose)]
        var lastSecond = 0

        /// Shows `pose` on the next free second at or after `offset` (at least `gap` after the last frame).
        func add(after gap: Int = 1, at offset: Double? = nil) {
            var second = lastSecond + gap
            if let offset { second = max(second, Int(offset.rounded(.up))) }
            // Always move the clock forward, even past the end, so the planning loop finishes.
            defer { lastSecond = second }
            guard Double(second) < duration else { return }
            frames.append(Frame(date: start.addingTimeInterval(Double(second)), pose: pose))
        }

        /// Bounces over to `target` in small hops: up, down, up, down, then a settle.
        func travel(to target: Double, stepSize: Double, height: Double) {
            let dir = target > pose.x ? 1 : -1
            while abs(target - pose.x) > 0.02 {
                let step = min(stepSize, abs(target - pose.x))
                // Up: halfway through the step, in the air.
                pose = BuddyPose(x: pose.x + Double(dir) * step / 2, lift: height, dir: dir)
                add()
                // Down: lands the rest of the way.
                pose = BuddyPose(x: pose.x + Double(dir) * step / 2, lift: 0, dir: dir, landing: height > 0.1)
                add()
            }
            pose = BuddyPose(x: pose.x)
            add()
        }

        func blink() {
            pose.eyesClosed = true
            add()
            pose.eyesClosed = false
            add()
        }

        func pickTarget(minDistance: Double) -> Double {
            var candidate = Double.random(in: 0...1, using: &rng)
            for _ in 0..<8 where abs(candidate - pose.x) < minDistance {
                candidate = Double.random(in: 0...1, using: &rng)
            }
            return candidate
        }

        // Leave room at the end so a walk never stops mid-air.
        while Double(lastSecond) < duration - 14 {
            switch energy {
            case .lively:
                travel(to: pickTarget(minDistance: 0.35), stepSize: 0.16, height: 1)
                if Bool.random(using: &rng) {
                    // A happy hop on the spot.
                    pose = BuddyPose(x: pose.x, lift: 0.8); add()
                    pose = BuddyPose(x: pose.x, landing: true); add()
                    pose = BuddyPose(x: pose.x); add()
                }
                add(after: Int.random(in: 1...2, using: &rng))
                blink()
                add(after: Int.random(in: 1...3, using: &rng))

            case .calm:
                travel(to: pickTarget(minDistance: 0.25), stepSize: 0.12, height: 0.6)
                add(after: Int.random(in: 2...4, using: &rng))
                blink()
                add(after: Int.random(in: 3...6, using: &rng))

            case .low:
                // A slow shuffle, no hopping.
                let target = min(1, max(0, pose.x + Double.random(in: -0.25...0.25, using: &rng)))
                travel(to: target, stepSize: 0.07, height: 0)
                add(after: Int.random(in: 4...7, using: &rng))
                blink()
                add(after: Int.random(in: 6...10, using: &rng))

            case .dozing:
                // Stays put and sleeps; the dozing face does the work.
                add(after: 30)
            }
        }
        // Make sure the plan ends standing, eyes open.
        if var last = frames.popLast() {
            last.pose = BuddyPose(x: last.pose.x)
            frames.append(last)
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
