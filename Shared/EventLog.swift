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

/// Append-only log stored as one JSON object per line in the App Group.
///
/// Never call this from inside a `SharedStore.update` closure: both use file coordination,
/// and nesting them can deadlock.
enum EventLog {
    private static var url: URL { AppGroup.fileURL("events.jsonl") }

    static func append(
        _ type: EventType,
        minutes: Int? = nil,
        sessionID: UUID? = nil,
        detail: String? = nil,
        at timestamp: Date = .now,
        group: StudyGroup? = nil
    ) {
        let event = LoggedEvent(
            timestamp: timestamp,
            loggedAt: .now,
            type: type,
            group: group ?? SharedStore.load().study.group,
            minutes: minutes,
            sessionID: sessionID?.uuidString,
            detail: detail
        )
        guard var line = try? encoder.encode(event) else { return }
        line.append(0x0A) // newline

        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { writeURL in
            if !FileManager.default.fileExists(atPath: writeURL.path) {
                FileManager.default.createFile(atPath: writeURL.path, contents: nil)
            }
            guard let handle = try? FileHandle(forWritingTo: writeURL) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        }
    }

    static func all() -> [LoggedEvent] {
        var events: [LoggedEvent] = []
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
            guard let data = try? Data(contentsOf: readURL) else { return }
            events = data.split(separator: 0x0A).compactMap { try? decoder.decode(LoggedEvent.self, from: Data($0)) }
        }
        return events.sorted { $0.timestamp < $1.timestamp }
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
