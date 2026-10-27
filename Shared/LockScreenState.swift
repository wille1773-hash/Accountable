import Foundation
import ManagedSettings

/// What the lock screen should say: locked, on a break until a time, or in a timer with minutes left.
///
/// The lock screen extension can't read Accountable's saved data, but it can read Screen Time
/// settings (see ShieldAppearance). So this is passed as a small number, one bit per named store,
/// each bit a setting that changes nothing: "in-app purchases allowed".
///
/// Bits 0–1: 0 locked, 1 break, 2 timer. Bits 2–12: the minute of the day the break ends.
/// Bits 13–20: minutes left in the timer.
enum LockScreenState: Equatable {
    case locked
    case onBreak(until: Date)
    case session(minutesLeft: Int)

    init(_ state: SharedState, now: Date = .now) {
        if let session = state.session, session.windowEnd > now {
            self = .session(minutesLeft: max(1, session.requestedMinutes - session.usedMinutes))
        } else if let lockout = state.lockout, lockout.endsAt > now {
            self = .onBreak(until: lockout.endsAt)
        } else {
            self = .locked
        }
    }

    private static let bitCount = 21
    /// A break further away than this is treated as one that has already ended (the bits only hold
    /// a time of day). Breaks are at most a few hours.
    private static let longestBreak = 5 * 60

    private static func store(_ bit: Int) -> ManagedSettingsStore {
        ManagedSettingsStore(named: .init("lockscreen.\(bit)"))
    }

    private var value: Int {
        switch self {
        case .locked:
            return 0
        case .onBreak(let until):
            return 1 | (Self.minuteOfDay(until) << 2)
        case .session(let left):
            return 2 | (min(left, 255) << 13)
        }
    }

    /// Saves what the lock screen should say. Only bits that changed are written.
    static func publish(_ state: SharedState) {
        guard !DemoMode.isOn else { return }
        let value = LockScreenState(state).value
        for bit in 0..<bitCount {
            let wanted: Bool? = value & (1 << bit) != 0 ? false : nil
            let store = store(bit)
            if store.appStore.denyInAppPurchases != wanted { store.appStore.denyInAppPurchases = wanted }
        }
    }

    /// Read by the lock screen.
    static func read(now: Date = .now) -> LockScreenState {
        var value = 0
        for bit in 0..<bitCount where store(bit).appStore.denyInAppPurchases != nil {
            value |= 1 << bit
        }
        switch value & 3 {
        case 1:
            // A time of day: work out how far ahead it is, wrapping past midnight.
            let ahead = ((value >> 2 & 0x7FF) - minuteOfDay(now) + 1440) % 1440
            guard ahead > 0, ahead <= longestBreak else { return .locked }
            let thisMinute = Calendar.current.dateInterval(of: .minute, for: now)?.start ?? now
            return .onBreak(until: thisMinute.addingTimeInterval(Double(ahead) * 60))
        case 2:
            return .session(minutesLeft: max(1, value >> 13 & 0xFF))
        default:
            return .locked
        }
    }

    private static func minuteOfDay(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
