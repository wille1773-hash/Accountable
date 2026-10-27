import Foundation

/// What gets logged for the study. App-level only: no app names (iOS doesn't give us them),
/// and nothing about what was viewed inside an app.
enum EventType: String, Codable {
    case consentGiven = "consent_given"
    case studyEnrolled = "study_enrolled"
    case sessionRequested = "session_requested"
    case sessionStarted = "session_started"
    case sessionStartFailed = "session_start_failed"
    case sessionEnded = "session_ended"
    case limitReached = "limit_reached"
    case lockoutStarted = "lockout_started"
    case lockoutEnded = "lockout_ended"
    /// The lock screen was drawn over a selected app. Best effort: see ShieldConfigurationExtension.
    case shieldShown = "shield_shown"
    /// A button on the lock screen was tapped.
    case shieldButtonTapped = "shield_button_tapped"
    case selectionChanged = "selection_changed"
    case authorizationLost = "authorization_lost"
    case authorizationRestored = "authorization_restored"
}

struct LoggedEvent: Codable {
    /// When it happened.
    var timestamp: Date
    /// When it was written. Differs from `timestamp` for events noticed after the fact,
    /// like a cooldown that ended while the app was closed.
    var loggedAt: Date
    var type: EventType
    var group: StudyGroup
    var minutes: Int?
    var sessionID: String?
    var detail: String?
}

/// Append-only log, one JSON object per line, kept in the shared keychain.
///
/// Never call this from inside a `SharedStore.update` closure: `update` holds the shared lock
/// while it runs, and logging reads the study settings through `SharedStore`.
enum EventLog {
    private static let key = "events"

    /// Records an event, but only for a study participant who has given consent.
    /// For everyone else this does nothing: regular users are never logged.
    static func append(
        _ type: EventType,
        minutes: Int? = nil,
        sessionID: UUID? = nil,
        detail: String? = nil,
        at timestamp: Date = .now
    ) {
        let study = SharedStore.load().study
        guard study.isLogging else { return }
        let event = LoggedEvent(
            timestamp: timestamp,
            loggedAt: .now,
            type: type,
            group: study.group,
            minutes: minutes,
            sessionID: sessionID?.uuidString,
            detail: detail
        )
        guard var line = try? encoder.encode(event) else { return }
        line.append(0x0A) // newline

        SharedKeychain.lock.lock(); defer { SharedKeychain.lock.unlock() }
        var log = SharedKeychain.read(key) ?? Data()
        log.append(line)
        SharedKeychain.write(log, for: key)
    }

    static func all() -> [LoggedEvent] {
        SharedKeychain.lock.lock(); defer { SharedKeychain.lock.unlock() }
        guard let data = SharedKeychain.read(key) else { return [] }
        return data.split(separator: 0x0A)
            .compactMap { try? decoder.decode(LoggedEvent.self, from: Data($0)) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
