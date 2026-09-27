import Foundation

/// Screen Time doesn't run in the Simulator, so there the app runs a pretend version:
/// no real permission or locking, and sessions and breaks run on a fast clock.
/// On a real iPhone this is always off.
enum DemoMode {
    #if targetEnvironment(simulator)
    static let isOn = true
    #else
    static let isOn = false
    #endif

    /// Real seconds per pretend minute. 2 means a 10 minute session lasts 20 seconds.
    static let secondsPerMinute: Double = 2

    /// Length of a "minute" for timing sessions and breaks.
    static var minute: TimeInterval { isOn ? secondsPerMinute : 60 }

    /// Converts real seconds to what they represent on the demo clock, for display.
    static func displaySeconds(_ real: TimeInterval) -> TimeInterval {
        isOn ? real * 60 / secondsPerMinute : real
    }

    static let appNames = ["TikTok", "Instagram", "YouTube"]
}
