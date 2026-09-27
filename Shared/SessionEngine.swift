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
        var logDetail: String {
            switch self {
            case .limitReached: "limit_reached"
            case .windowEnded: "window_closed"
            case .userEnded: "ended_by_user"
            case .monitoringLost: "monitoring_lost"
            case .authorizationLost: "authorization_lost"
            }
        }

        /// The requested time was used up. Counts as a broken promise.
        case limitReached
        /// The backstop window closed before the time was used up. Counts as kept.
        case windowEnded
        /// The user tapped "I'm done". Counts as kept.
        case userEnded
        /// iOS stopped monitoring the session (for example, it didn't survive a restart). Counts as kept,
        /// since the user didn't run out of time.
        case monitoringLost
        /// Screen Time access was turned off mid-session. Counted as neither kept nor broken.
        case authorizationLost
    }

    static let minimumWindow: TimeInterval = 15 * 60
    /// Most progress markers per session, to stay well under the system's limit on events.
    static let maxProgressMarkers = 30

    // MARK: Start

    @discardableResult
    static func start(minutes: Int, now: Date = .now) throws -> ActiveSession {
        logLockoutEndIfNeeded(now: now)
        let state = SharedStore.load()
        if let lockout = state.lockout, lockout.endsAt > now { throw StartError.coolingDown(until: lockout.endsAt) }
        if let session = state.session, session.windowEnd > now { throw StartError.alreadyRunning }
        guard state.hasSelection || DemoMode.isOn else { throw StartError.nothingSelected }

        var session = ActiveSession(
            id: UUID(),
            requestedMinutes: minutes,
            startedAt: now,
            windowEnd: now.addingTimeInterval(max(minimumWindow, Double(minutes) * 60 * 2))
        )

        if DemoMode.isOn {
            // No Screen Time in the Simulator: the app advances the session itself (see AppModel).
            session.windowEnd = now.addingTimeInterval(Double(minutes) * DemoMode.minute * 2)
            SharedStore.update { state in
                state.session = session
                state.days[DayKey.string(for: now), default: DayStats()].made += 1
            }
            return session
        }

        let center = DeviceActivityCenter()
        center.stopMonitoring()
        let events = events(for: minutes, selection: state.selection)
        do {
            try center.startMonitoring(.session(session.id), during: schedule(for: session, now: now), events: events)
        } catch DeviceActivityCenter.MonitoringError.invalidDateComponents {
            // If iOS won't accept a window that crosses midnight, end it at midnight instead.
            session.windowEnd = min(session.windowEnd, endOfDay(now))
            try center.startMonitoring(.session(session.id), during: timeOfDaySchedule(for: session, now: now), events: events)
        }

        SharedStore.update { state in
            state.session = session
            state.days[DayKey.string(for: now), default: DayStats()].made += 1
        }
        Shielding.unlock()
        EventLog.append(.sessionStarted, minutes: minutes, sessionID: session.id, at: now)
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

    /// Fallback schedule using times of day only, which can't cross midnight.
    private static func timeOfDaySchedule(for session: ActiveSession, now: Date) -> DeviceActivitySchedule {
        let calendar = Calendar.current
        let start = max(calendar.startOfDay(for: now), min(now, session.windowEnd.addingTimeInterval(-minimumWindow)))
        return DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: start),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: session.windowEnd),
            repeats: false
        )
    }

    /// 23:59:59 on the day of `date`.
    private static func endOfDay(_ date: Date) -> Date {
        let calendar = Calendar.current
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        return startOfTomorrow.addingTimeInterval(-1)
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
            if reason == .authorizationLost || reason == .monitoringLost {
                // Not the user's doing, so Buddy's mood doesn't change.
                if reason == .monitoringLost { state.days[day, default: DayStats()].kept += 1 }
            } else if reason == .limitReached {
                state.buddyHealth = BuddyHealth.clamp(state.buddyHealth - BuddyHealth.brokenLoss)
                state.days[day, default: DayStats()].limitsHit += 1
                // Escalation counts limit hits on the calendar day the limit was hit,
                // so it resets at midnight even if the session started yesterday.
                state.limitHitsByDay[DayKey.string(for: now), default: 0] += 1
                let hitsToday = state.limitHitsByDay[DayKey.string(for: now)] ?? 1
                let minutes = CooldownPolicy.minutes(forHitNumber: hitsToday, state: state)
                state.lockout = Lockout(startedAt: now, endsAt: now.addingTimeInterval(Double(minutes) * DemoMode.minute), minutes: minutes)
            } else {
                // A session ended within a minute doesn't cheer Buddy up, so the mood can't be farmed.
                if now.timeIntervalSince(session.startedAt) >= DemoMode.minute {
                    state.buddyHealth = BuddyHealth.clamp(state.buddyHealth + BuddyHealth.keptGain)
                }
                state.days[day, default: DayStats()].kept += 1
            }
        }
        guard let session = ended else { return }

        if !DemoMode.isOn {
            Shielding.lock(state.selection)
            DeviceActivityCenter().stopMonitoring([.session(session.id)])
        }
        switch reason {
        case .limitReached:
            EventLog.append(.limitReached, minutes: session.requestedMinutes, sessionID: session.id, at: now)
            if let lockout = state.lockout {
                EventLog.append(.lockoutStarted, minutes: lockout.minutes, sessionID: session.id, at: lockout.startedAt)
            }
        case .windowEnded, .userEnded, .monitoringLost, .authorizationLost:
            EventLog.append(.sessionEnded, minutes: session.usedMinutes, sessionID: session.id, detail: reason.logDetail, at: now)
        }

        if reason == .limitReached, let lockout = state.lockout {
            let time = lockout.endsAt.formatted(date: .omitted, time: .shortened)
            Notifier.post(
                id: "time-up",
                title: "Time's up",
                body: "That's the \(session.requestedMinutes) minutes you asked for. You can start another session at \(time)."
            )
        }
    }

    /// Nothing runs at the moment a cooldown ends (Apple's schedules can't be that short, and nothing
    /// needs unlocking), so "lockout ended" is written the next time any part of the app runs,
    /// stamped with the time the cooldown actually ended.
    static func logLockoutEndIfNeeded(now: Date = .now) {
        // Cheap read first: this runs every few seconds while the app is open.
        guard let current = SharedStore.load().lockout, current.endsAt <= now, !current.endLogged else { return }
        var finished: Lockout?
        SharedStore.update { state in
            guard var lockout = state.lockout, lockout.endsAt <= now, !lockout.endLogged else { return }
            lockout.endLogged = true
            state.lockout = lockout
            finished = lockout
        }
        if let finished {
            EventLog.append(.lockoutEnded, minutes: finished.minutes, at: finished.endsAt)
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

    /// Ends a session iOS is no longer monitoring. Without monitoring, nothing would re-lock the apps.
    /// Monitoring normally survives a restart; this is the safety net if it doesn't.
    static func finishIfMonitoringLost(now: Date = .now) {
        guard !DemoMode.isOn else { return }
        let state = SharedStore.load()
        guard let session = state.session, session.windowEnd > now,
              // Give iOS a moment to register a session that just started.
              now.timeIntervalSince(session.startedAt) > 10 else { return }
        if !DeviceActivityCenter().activities.contains(.session(session.id)) {
            finish(sessionID: session.id, reason: .monitoringLost, now: now)
        }
    }
}
