import Foundation
import FamilyControls

/// A session the user asked for ("15 minutes, please").
struct ActiveSession: Codable, Equatable {
    var id: UUID
    var requestedMinutes: Int
    var startedAt: Date
    /// Wall-clock backstop. If usage tracking never reports the limit, the session still ends here.
    var windowEnd: Date
    /// Minutes of use reported so far by the monitor extension.
    var usedMinutes: Int = 0
}

/// A cooldown after hitting a limit. No new session can start until `endsAt`.
struct Lockout: Codable, Equatable {
    var startedAt: Date
    var endsAt: Date
    var minutes: Int
    /// Set once "lockout ended" has been written to the event log.
    var endLogged: Bool = false
}

/// Promises for one calendar day.
struct DayStats: Codable, Equatable {
    /// Sessions started.
    var made = 0
    /// Sessions that ended before the time ran out.
    var kept = 0
    /// Sessions where the time ran out and the apps had to lock.
    var limitsHit = 0
    /// Minutes spent in the selected apps during sessions that started this day.
    /// Since the apps are locked outside sessions, this is the day's total on them.
    var minutesUsed = 0

    init(made: Int = 0, kept: Int = 0, limitsHit: Int = 0, minutesUsed: Int = 0) {
        self.made = made
        self.kept = kept
        self.limitsHit = limitsHit
        self.minutesUsed = minutesUsed
    }

    // Field by field, so days saved by an older version still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        made = (try? c.decodeIfPresent(Int.self, forKey: .made)) ?? 0
        kept = (try? c.decodeIfPresent(Int.self, forKey: .kept)) ?? 0
        limitsHit = (try? c.decodeIfPresent(Int.self, forKey: .limitsHit)) ?? 0
        minutesUsed = (try? c.decodeIfPresent(Int.self, forKey: .minutesUsed)) ?? 0
    }
}

/// One finished promise, for the "recent promises" row and "kept in a row".
struct PromiseRecord: Codable, Equatable {
    var kept: Bool
    var at: Date
}

enum StudyGroup: String, Codable, CaseIterable, Identifiable {
    case none, flat, escalating
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: "Not assigned"
        case .flat: "Flat"
        case .escalating: "Escalating"
        }
    }
}

struct CooldownSettings: Codable, Equatable {
    var escalating = true
    var flatMinutes = 10
    var steps = [3, 10, 30, 60]
}

/// How Buddy's mood moves. Breaking a promise costs more than keeping one earns, so the only
/// way back up is a run of kept promises.
enum BuddyHealth {
    static let range = 0...10
    static let start = 6
    static let keptGain = 1
    static let brokenLoss = 2

    static func clamp(_ value: Int) -> Int { min(range.upperBound, max(range.lowerBound, value)) }
}

struct Profile: Codable, Equatable {
    /// Typical daily social media time, in minutes. Defaults to the global average (about 2h 20m).
    var dailyMinutes = 140
    var age = 20
}

struct StudySettings: Codable, Equatable {
    var participantID = ""
    var group: StudyGroup = .none
    var consentedAt: Date?

    var isEnrolled: Bool { !participantID.isEmpty && group != .none }
    /// Logging only happens for enrolled participants who have agreed to the consent screen.
    var isLogging: Bool { isEnrolled && consentedAt != nil }
}

/// Everything shared between the app and its extensions, stored as one JSON file in the App Group.
struct SharedState: Codable {
    var selection = FamilyActivitySelection()
    var hasCompletedSetup = false
    var session: ActiveSession?
    var lockout: Lockout?
    /// Keyed by `DayKey.string(for:)`.
    var days: [String: DayStats] = [:]
    /// The first day the app was set up, so the streak doesn't count days before install.
    var firstDay: String?
    var cooldown = CooldownSettings()
    var study = StudySettings()
    /// Limit hits per calendar day they happened on, for escalating breaks. Separate from `days`,
    /// which files a session under the day it started, so a session that runs past midnight
    /// still escalates correctly.
    var limitHitsByDay: [String: Int] = [:]
    /// True once Screen Time access has been granted, so we can tell when it's been taken away.
    var wasAuthorized = false
    /// Finished the intro walkthrough.
    var hasSeenIntro = false
    /// What the user told us in the intro, for the lifetime projection. Never logged.
    var profile = Profile()
    /// Buddy's mood, 0 (miserable) to 10 (thriving). Kept promises raise it, broken ones lower it.
    var buddyHealth = BuddyHealth.start
    /// Names of the pretend apps picked in the Simulator demo.
    var demoApps: [String] = []
    /// The most recent finished promises, newest last. Old ones roll off, so a run of kept
    /// promises always wins back a bad stretch.
    var recentPromises: [PromiseRecord] = []
    /// Bumped when Buddy is tapped on a widget, to make Buddy hop.
    var widgetHops = 0

    init() {}

    // Decode field by field so adding a field in a later version never wipes existing data.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        selection = (try? c.decodeIfPresent(FamilyActivitySelection.self, forKey: .selection)) ?? FamilyActivitySelection()
        hasCompletedSetup = (try? c.decodeIfPresent(Bool.self, forKey: .hasCompletedSetup)) ?? false
        session = try? c.decodeIfPresent(ActiveSession.self, forKey: .session)
        lockout = try? c.decodeIfPresent(Lockout.self, forKey: .lockout)
        days = (try? c.decodeIfPresent([String: DayStats].self, forKey: .days)) ?? [:]
        firstDay = try? c.decodeIfPresent(String.self, forKey: .firstDay)
        cooldown = (try? c.decodeIfPresent(CooldownSettings.self, forKey: .cooldown)) ?? CooldownSettings()
        study = (try? c.decodeIfPresent(StudySettings.self, forKey: .study)) ?? StudySettings()
        wasAuthorized = (try? c.decodeIfPresent(Bool.self, forKey: .wasAuthorized)) ?? false
        limitHitsByDay = (try? c.decodeIfPresent([String: Int].self, forKey: .limitHitsByDay)) ?? [:]
        hasSeenIntro = (try? c.decodeIfPresent(Bool.self, forKey: .hasSeenIntro)) ?? false
        profile = (try? c.decodeIfPresent(Profile.self, forKey: .profile)) ?? Profile()
        buddyHealth = (try? c.decodeIfPresent(Int.self, forKey: .buddyHealth)) ?? BuddyHealth.start
        demoApps = (try? c.decodeIfPresent([String].self, forKey: .demoApps)) ?? []
        recentPromises = (try? c.decodeIfPresent([PromiseRecord].self, forKey: .recentPromises)) ?? []
        widgetHops = (try? c.decodeIfPresent(Int.self, forKey: .widgetHops)) ?? 0
    }

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
    }
}

enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(for date: Date) -> String {
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        formatter.timeZone = .current
        return formatter.date(from: string)
    }
}
