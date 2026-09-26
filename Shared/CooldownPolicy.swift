import Foundation

/// How long the break is after hitting a limit.
///
/// Flat: every break is `flatMinutes`.
/// Escalating: the Nth limit hit today gets `steps[N-1]`, staying on the last step after that.
/// Counts reset at midnight because they're read from today's stats.
///
/// If the participant is enrolled in the study, their group decides the mode and they can't change it.
enum CooldownPolicy {
    static func isEscalating(_ state: SharedState) -> Bool {
        switch state.study.group {
        case .flat: false
        case .escalating: true
        case .none: state.cooldown.escalating
        }
    }

    /// Break length for the `hitNumber`-th limit hit today (1-based).
    static func minutes(forHitNumber hitNumber: Int, state: SharedState) -> Int {
        guard isEscalating(state) else { return max(1, state.cooldown.flatMinutes) }
        let steps = state.cooldown.steps.isEmpty ? CooldownSettings().steps : state.cooldown.steps
        let index = min(max(hitNumber, 1) - 1, steps.count - 1)
        return max(1, steps[index])
    }

    /// Break length if the user hits the limit once more today. Shown on the home screen.
    static func nextMinutes(state: SharedState, now: Date = .now) -> Int {
        let hitsToday = state.days[DayKey.string(for: now)]?.limitsHit ?? 0
        return minutes(forHitNumber: hitsToday + 1, state: state)
    }
}
