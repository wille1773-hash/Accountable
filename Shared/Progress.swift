import Foundation

/// Forgiving progress numbers. Nothing here is a permanent score: a run of kept promises
/// always pushes older broken ones out of view.
enum Progress {
    /// How many finished promises to remember.
    static let recentLimit = 20
    /// How many to show in the "recent promises" row.
    static let recentShown = 10

    /// Promises kept since the last one that ran out of time.
    static func keptInARow(_ state: SharedState) -> Int {
        var count = 0
        for record in state.recentPromises.reversed() {
            guard record.kept else { break }
            count += 1
        }
        return count
    }

    /// The last few promises, oldest first.
    static func recent(_ state: SharedState) -> [PromiseRecord] {
        Array(state.recentPromises.suffix(recentShown))
    }

    struct DayMinutes: Identifiable {
        var date: Date
        var minutes: Int
        var id: Date { date }
    }

    /// Minutes in the selected apps for each of the last seven days, oldest first.
    static func week(_ state: SharedState, now: Date = .now, calendar: Calendar = .current) -> [DayMinutes] {
        let today = calendar.startOfDay(for: now)
        return (0..<7).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { return nil }
            return DayMinutes(date: day, minutes: state.days[DayKey.string(for: day)]?.minutesUsed ?? 0)
        }
    }

    /// Average minutes a day over the last seven full days since setup.
    ///
    /// The setup day is skipped (it's usually a partial day, which would make the average look
    /// better than it is), and so is today (not over yet). Nil until there's a full day of data.
    /// The Simulator demo has no history to wait for, so it averages every day since setup, today included.
    static func averageDailyMinutes(_ state: SharedState, now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let firstKey = state.firstDay, let first = DayKey.date(from: firstKey) else { return nil }
        let today = calendar.startOfDay(for: now)
        let setupDay = calendar.startOfDay(for: first)
        let span = calendar.dateComponents([.day], from: setupDay, to: today).day ?? 0

        let backs: [Int] = DemoMode.isOn
            ? Array(0...max(0, span))                   // today back to the setup day
            : Array(1..<max(1, min(8, span)))           // yesterday back, at most 7, never the setup day
        guard !backs.isEmpty else { return nil }
        let total = backs.reduce(0) { sum, back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { return sum }
            return sum + (state.days[DayKey.string(for: day)]?.minutesUsed ?? 0)
        }
        return Int((Double(total) / Double(backs.count)).rounded())
    }
}
