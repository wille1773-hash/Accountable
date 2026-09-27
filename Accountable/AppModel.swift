import Combine
import FamilyControls
import Foundation

/// The app's view of the shared state, plus the actions the UI can take.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state = SharedStore.load()
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
        DemoMode.isOn ? "\(DemoMode.appNames.count) demo apps" : state.selection.summary
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
    }

    /// Lighter than `refresh()`: just picks up changes from the extensions.
    private func poll() {
        if DemoMode.isOn { advanceDemoSession() }
        SessionEngine.finishIfWindowPassed()
        SessionEngine.logLockoutEndIfNeeded()
        let latest = SharedStore.load()
        if latest.session != state.session || latest.lockout != state.lockout || latest.days != state.days {
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
        // Counts only: iOS doesn't reveal which apps were picked.
        let counts = "apps=\(selection.applicationTokens.count);categories=\(selection.categoryTokens.count);websites=\(selection.webDomainTokens.count)"
        EventLog.append(.selectionChanged, detail: (wasSetUp ? "changed;" : "initial;") + counts)
        Task { await Notifier.requestPermission() }
    }

    // MARK: Sessions

    func startSession(minutes: Int) throws {
        EventLog.append(.sessionRequested, minutes: minutes)
        do {
            try SessionEngine.start(minutes: minutes)
        } catch {
            EventLog.append(.sessionStartFailed, minutes: minutes, detail: String(describing: error))
            throw error
        }
        refresh()
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

    // MARK: Settings

    func updateCooldown(_ settings: CooldownSettings) {
        state = SharedStore.update { $0.cooldown = settings }
    }
}
