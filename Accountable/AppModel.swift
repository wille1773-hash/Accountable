import Combine
import DeviceActivity
import FamilyControls
import Foundation
import UserNotifications

/// The app's view of the shared state, plus the actions the UI can take.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: SharedState = {
        SharedKeychain.clearIfFreshInstall()
        return SharedStore.load()
    }()
    @Published private(set) var authorizationStatus = AuthorizationCenter.shared.authorizationStatus

    private var cancellables = Set<AnyCancellable>()
    /// Consecutive checks that found Screen Time access missing. iOS can briefly report
    /// "not determined" at launch, so a single miss isn't treated as a revocation.
    private var authorizationMisses = 0

    init() {
        AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.authorizationStatus = status
                self?.checkAuthorization()
            }
            .store(in: &cancellables)

        // The monitor extension updates the shared file in the background (progress, time's up).
        // Re-read it regularly while the app is open so the screen stays current.
        Timer.publish(every: DemoMode.isOn ? 1 : 3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.poll() }
            .store(in: &cancellables)
    }

    var isAuthorized: Bool {
        DemoMode.isOn ? state.wasAuthorized : authorizationStatus == .approved
    }

    var hasSelection: Bool { DemoMode.isOn ? state.hasCompletedSetup : state.hasSelection }

    /// e.g. "3 apps, 1 category"
    var selectionSummary: String {
        guard DemoMode.isOn else { return state.selection.summary }
        let apps = state.demoApps
        return apps.count <= 2 ? apps.joined(separator: " and ") : "\(apps.count) apps"
    }

    /// Re-reads the shared file, picking up anything the extensions changed while the app was closed.
    func refresh() {
        SessionEngine.finishIfWindowPassed()
        SessionEngine.finishIfMonitoringLost()
        SessionEngine.logLockoutEndIfNeeded()
        state = SharedStore.load()
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        checkAuthorization()
        reassertLock()
        if state.wantsCustomTime {
            state = SharedStore.update { $0.wantsCustomTime = false }
            showTimePicker = true
        }
    }

    /// Lighter than `refresh()`: just picks up changes from the extensions.
    private func poll() {
        if DemoMode.isOn { advanceDemoSession() }
        SessionEngine.finishIfWindowPassed()
        SessionEngine.logLockoutEndIfNeeded()
        let latest = SharedStore.load()
        if latest.session != state.session || latest.lockout != state.lockout || latest.days != state.days
            || latest.buddyHealth != state.buddyHealth || latest.recentPromises != state.recentPromises {
            state = latest
        }
        checkAuthorization()
    }

    /// In the Simulator, pretend the user is on their apps for the whole session.
    private func advanceDemoSession() {
        guard let session = SharedStore.load().session else { return }
        let used = Int(Date.now.timeIntervalSince(session.startedAt) / DemoMode.minute)
        if used >= session.requestedMinutes {
            SessionEngine.finish(sessionID: session.id, reason: .limitReached)
        } else if used > session.usedMinutes {
            SessionEngine.recordProgress(sessionID: session.id, minutes: used)
        }
    }

    /// Apps are locked whenever there's no session running. Re-applying the lock is harmless,
    /// and it repairs things if a shield was lost (for example after changing the app selection).
    private func reassertLock() {
        guard !DemoMode.isOn, isAuthorized, state.hasCompletedSetup, state.session == nil else { return }
        Shielding.lock(state.selection)
    }

    /// Notices Screen Time access being turned off (in Settings) or back on, and logs it.
    /// When it's off, iOS removes the locks and stops monitoring, so any running session is over.
    private func checkAuthorization() {
        guard !DemoMode.isOn else { return }
        let approved = AuthorizationCenter.shared.authorizationStatus == .approved
        if approved {
            authorizationMisses = 0
            if !state.wasAuthorized {
                let wasSetUp = state.hasCompletedSetup
                state = SharedStore.update { $0.wasAuthorized = true }
                if wasSetUp { EventLog.append(.authorizationRestored) }
            }
            return
        }
        guard state.wasAuthorized else { return }
        authorizationMisses += 1
        guard authorizationMisses >= 2 else { return }

        if let session = state.session {
            SessionEngine.finish(sessionID: session.id, reason: .authorizationLost)
        }
        state = SharedStore.update { $0.wasAuthorized = false }
        EventLog.append(.authorizationLost)
    }

    // MARK: Setup

    func finishIntro(profile: Profile) {
        state = SharedStore.update { state in
            state.profile = profile
            state.hasSeenIntro = true
        }
    }

    func updateProfile(_ change: (inout Profile) -> Void) {
        state = SharedStore.update { change(&$0.profile) }
    }

    func requestAuthorization() async throws {
        if DemoMode.isOn {
            state = SharedStore.update { $0.wasAuthorized = true }
            return
        }
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        refresh()
    }

    func saveSelection(_ selection: FamilyActivitySelection) {
        let wasSetUp = state.hasCompletedSetup
        state = SharedStore.update { state in
            state.selection = selection
            state.hasCompletedSetup = true
            if state.firstDay == nil { state.firstDay = DayKey.string(for: .now) }
        }
        reassertLock()
        SessionEngine.selectionChanged()
        // Counts only: iOS doesn't reveal which apps were picked.
        let counts = "apps=\(selection.applicationTokens.count);categories=\(selection.categoryTokens.count);websites=\(selection.webDomainTokens.count)"
        EventLog.append(.selectionChanged, detail: (wasSetUp ? "changed;" : "initial;") + counts)
    }

    /// Simulator only: remember the pretend apps.
    func saveDemoApps(_ apps: [String]) {
        state = SharedStore.update { state in
            state.demoApps = apps
            state.hasCompletedSetup = true
            if state.firstDay == nil { state.firstDay = DayKey.string(for: .now) }
        }
    }

    // MARK: Sessions

    /// True while a break is running.
    var onBreak: Bool { (state.lockout?.endsAt ?? .distantPast) > .now }

    /// Set when the lock screen's "Custom time…" opened the app; the home screen shows the time picker.
    @Published var showTimePicker = false

    func startSession(minutes: Int, breakingPromise: Bool = false) throws {
        EventLog.append(.sessionRequested, minutes: minutes)
        do {
            // Set in Accountable: every app opens on this one timer.
            try SessionEngine.start(minutes: minutes, breakingPromise: breakingPromise, opening: .all(state.selection))
        } catch {
            EventLog.append(.sessionStartFailed, minutes: minutes, detail: String(describing: error))
            throw error
        }
        refresh()
        // Asked here rather than at setup, when it's clear what the notifications are for:
        // "about a minute left" and "time's up". iOS only shows the prompt the first time.
        Task { await Notifier.requestPermission() }
    }

    func endSessionEarly() {
        guard let session = state.session else { return }
        SessionEngine.finish(sessionID: session.id, reason: .userEnded)
        refresh()
    }

    // MARK: Study

    /// True when a researcher has enrolled this phone but the participant hasn't agreed yet.
    var needsConsent: Bool { state.study.isEnrolled && state.study.consentedAt == nil }

    func giveConsent() {
        state = SharedStore.update { $0.study.consentedAt = .now }
        EventLog.append(.consentGiven, detail: state.study.participantID)
    }

    /// The participant said no: remove the enrollment so nothing is logged.
    func declineConsent() {
        state = SharedStore.update { $0.study = StudySettings() }
    }

    func enroll(participantID: String, group: StudyGroup, cooldown: CooldownSettings) {
        let previous = state.study
        state = SharedStore.update { state in
            if state.study.participantID != participantID { state.study.consentedAt = nil }
            state.study.participantID = participantID
            state.study.group = group
            state.cooldown = cooldown
        }
        if previous.group != group { EventLog.append(.studyEnrolled, detail: "group=\(group.rawValue)") }
    }

    /// Back to the regular app: logging stops and the study section is hidden. The log itself stays
    /// on the phone, so enrolling again with the same participant ID can still export it.
    func leaveStudy() {
        state = SharedStore.update { $0.study = StudySettings() }
    }

    // MARK: Settings

    func updateCooldown(_ settings: CooldownSettings) {
        state = SharedStore.update { $0.cooldown = settings }
    }

    // MARK: Start over

    /// Puts the app back the way it is right after a download: no locks, no tracking, no data,
    /// and Screen Time access turned off so the permission step shows again.
    func startOver() {
        if !DemoMode.isOn {
            DeviceActivityCenter().stopMonitoring()
            Shielding.clearAll()
            AuthorizationCenter.shared.revokeAuthorization { _ in }
        }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        SharedKeychain.removeAll()
        authorizationMisses = 0
        state = SharedStore.load()
    }
}
