import Foundation

/// Days in a row, ending today, where no session ran out of time.
///
/// Days with no sessions count as kept: not opening the apps at all is keeping your word too.
/// Today counts as long as no limit has been hit yet. Days before setup don't count.
enum Streak {
    static func days(in state: SharedState, now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let firstKey = state.firstDay, let firstDay = DayKey.date(from: firstKey) else { return 0 }
        let start = calendar.startOfDay(for: firstDay)
        var day = calendar.startOfDay(for: now)
        var count = 0
        while day >= start {
            if (state.days[DayKey.string(for: day)]?.limitsHit ?? 0) > 0 { break }
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
