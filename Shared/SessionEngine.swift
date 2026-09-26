import DeviceActivity
import FamilyControls
import Foundation

extension DeviceActivityName {
    private static let sessionPrefix = "session."

    static func session(_ id: UUID) -> Self { Self(sessionPrefix + id.uuidString) }

    /// The session this activity belongs to, so callbacks from an old session are ignored.
    var sessionID: UUID? {
        guard rawValue.hasPrefix(Self.sessionPrefix) else { return nil }
        return UUID(uuidString: String(rawValue.dropFirst(Self.sessionPrefix.count)))
    }
}

extension DeviceActivityEvent.Name {
    static let limit = Self("limit")

    static func progress(_ minutes: Int) -> Self { Self("progress.\(minutes)") }

    var progressMinutes: Int? {
        guard rawValue.hasPrefix("progress.") else { return nil }
        return Int(rawValue.dropFirst("progress.".count))
    }
}

/// Starts and ends sessions. Called from the app (start, "I'm done") and from the monitor
/// extension (limit reached, window over).
///
/// How a session works:
/// - Apple requires a monitoring schedule of at least 15 minutes, so the schedule ("window")
///   runs for max(15 min, 2 × the requested time). It's a backstop, not the limit.
/// - The limit itself is a usage threshold: iOS counts only the time the selected apps are
///   on screen, and tells the monitor extension when it reaches the requested minutes.
/// - Extra thresholds every few minutes let the app show roughly how much time is left.
enum SessionEngine {
    enum StartError: LocalizedError {
        case coolingDown(until: Date)
        case alreadyRunning
        case nothingSelected

        var errorDescription: String? {
            switch self {
            case .coolingDown(let until):
                "You can start a new session at \(until.formatted(date: .omitted, time: .shortened))."
            case .alreadyRunning:
                "A session is already running."
            case .nothingSelected:
                "Pick some apps first."
            }
        }
    }

    enum EndReason: String {
        /// The requested time was used up. Counts as a broken promise.
        case limitReached
        /// The backstop window closed before the time was used up. Counts as kept.
        case windowEnded
        /// The user tapped "I'm done". Counts as kept.
        case userEnded
    }

    static let minimumWindow: TimeInterval = 15 * 60
    /// Most progress markers per session, to stay well under the system's limit on events.
    static let maxProgressMarkers = 30

    // MARK: Start

    @discardableResult
    static func start(minutes: Int, now: Date = .now) throws -> ActiveSession {
        let state = SharedStore.load()
        if let lockout = state.lockout, lockout.endsAt > now { throw StartError.coolingDown(until: lockout.endsAt) }
        if let session = state.session, session.windowEnd > now { throw StartError.alreadyRunning }
        guard state.hasSelection else { throw StartError.nothingSelected }

        let session = ActiveSession(
            id: UUID(),
            requestedMinutes: minutes,
            startedAt: now,
            windowEnd: now.addingTimeInterval(max(minimumWindow, Double(minutes) * 60 * 2))
        )

        let center = DeviceActivityCenter()
        center.stopMonitoring()
        try center.startMonitoring(
            .session(session.id),
            during: schedule(for: session, now: now),
            events: events(for: minutes, selection: state.selection)
        )

        SharedStore.update { state in
            state.session = session
            state.days[DayKey.string(for: now), default: DayStats()].made += 1
        }
        Shielding.unlock()
        return session
    }

    private static func schedule(for session: ActiveSession, now: Date) -> DeviceActivitySchedule {
        // Full dates (not just times of day) so a window can run past midnight.
        let fields: Set<Calendar.Component> = [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second]
        let calendar = Calendar.current
        let start = min(now, session.windowEnd.addingTimeInterval(-minimumWindow))
        let warning: DateComponents? = session.requestedMinutes >= 3 ? DateComponents(minute: 1) : nil
        return DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(fields, from: start),
            intervalEnd: calendar.dateComponents(fields, from: session.windowEnd),
            repeats: false,
            warningTime: warning
        )
    }

    private static func events(for minutes: Int, selection: FamilyActivitySelection) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        let step = max(1, Int((Double(minutes) / Double(maxProgressMarkers)).rounded(.up)))
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [.limit: event(minutes: minutes, selection: selection)]
        for marker in stride(from: step, to: minutes, by: step) {
            events[.progress(marker)] = event(minutes: marker, selection: selection)
        }
        return events
    }

    private static func event(minutes: Int, selection: FamilyActivitySelection) -> DeviceActivityEvent {
        let threshold = DateComponents(minute: minutes)
        if #available(iOS 17.4, *) {
            // Only count use from the moment the session starts.
            return DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: threshold,
                includesPastActivity: false
            )
        }
        return DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: threshold
        )
    }

    // MARK: Progress and end

    static func recordProgress(sessionID: UUID, minutes: Int) {
        SharedStore.update { state in
            guard var session = state.session, session.id == sessionID else { return }
            session.usedMinutes = max(session.usedMinutes, minutes)
            state.session = session
        }
    }

    /// Ends the session, re-locks the apps and updates today's stats.
    /// Does nothing if that session already ended, so duplicate callbacks are safe.
    static func finish(sessionID: UUID, reason: EndReason, now: Date = .now) {
        var ended: ActiveSession?
        let state = SharedStore.update { state in
            guard let session = state.session, session.id == sessionID else { return }
            ended = session
            state.session = nil
            let day = DayKey.string(for: session.startedAt)
            if reason == .limitReached {
                state.days[day, default: DayStats()].limitsHit += 1
                // Escalation counts limit hits on the calendar day the limit was hit,
                // so it resets at midnight even if the session started yesterday.
                let hitsToday = state.days[DayKey.string(for: now)]?.limitsHit ?? 0
                let minutes = CooldownPolicy.minutes(forHitNumber: hitsToday, state: state)
                state.lockout = Lockout(startedAt: now, endsAt: now.addingTimeInterval(Double(minutes) * 60), minutes: minutes)
            } else {
                state.days[day, default: DayStats()].kept += 1
            }
        }
        guard let session = ended else { return }

        Shielding.lock(state.selection)
        DeviceActivityCenter().stopMonitoring([.session(session.id)])

        if reason == .limitReached, let lockout = state.lockout {
            let time = lockout.endsAt.formatted(date: .omitted, time: .shortened)
            Notifier.post(
                id: "time-up",
                title: "Time's up",
                body: "That's the \(session.requestedMinutes) minutes you asked for. You can start another session at \(time)."
            )
        }
    }

    /// Catches a session whose window closed without the extension hearing about it
    /// (for example, if the phone was off). Safe to call any time.
    static func finishIfWindowPassed(now: Date = .now) {
        let state = SharedStore.load()
        if let session = state.session, session.windowEnd <= now {
            finish(sessionID: session.id, reason: .windowEnded, now: now)
        }
    }
}
