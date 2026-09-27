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
        // Re-read it every few seconds while the app is open so the screen stays current.
        Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.poll() }
            .store(in: &cancellables)
    }

    var isAuthorized: Bool { authorizationStatus == .approved }

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
        SessionEngine.finishIfWindowPassed()
        SessionEngine.logLockoutEndIfNeeded()
        let latest = SharedStore.load()
        if latest.session != state.session || latest.lockout != state.lockout || latest.days != state.days {
            state = latest
        }
        checkAuthorization()
    }

    /// Notices Screen Time access being turned off (in Settings) or back on, and logs it.
    /// When it's off, iOS removes the locks and stops monitoring, so any running session is over.
    private func checkAuthorization() {
        let approved = AuthorizationCenter.shared.authorizationStatus == .approved
        if approved {
            authorizationMisses = 0
            if !state.wasAuthorized {
                let wasSetUp = state.hasCompletedSetup
                state = SharedStore.update { $0.wasAuthorized = true }
                if wasSetUp { EventLog.append(.authorizationRestored, group: state.study.group) }
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
        EventLog.append(.authorizationLost, group: state.study.group)
    }

    /// Apps are locked whenever there's no session running. Re-applying the lock is harmless,
    /// and it repairs things if a shield was lost (for example after changing the app selection).
    private func reassertLock() {
        guard isAuthorized, state.hasCompletedSetup, state.session == nil else { return }
        Shielding.lock(state.selection)
    }

    func requestAuthorization() async throws {
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
        EventLog.append(.selectionChanged, detail: (wasSetUp ? "changed;" : "initial;") + counts, group: state.study.group)
        Task { await Notifier.requestPermission() }
    }

    // MARK: Sessions

    func startSession(minutes: Int) throws {
        EventLog.append(.sessionRequested, minutes: minutes, group: state.study.group)
        do {
            try SessionEngine.start(minutes: minutes)
        } catch {
            EventLog.append(.sessionStartFailed, minutes: minutes, detail: String(describing: error), group: state.study.group)
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

    func giveConsent() {
        state = SharedStore.update { $0.study.consentedAt = .now }
        EventLog.append(.consentGiven, group: state.study.group)
    }

    func enroll(participantID: String, group: StudyGroup, cooldown: CooldownSettings) {
        state = SharedStore.update { state in
            state.study.participantID = participantID
            state.study.group = group
            state.cooldown = cooldown
        }
        EventLog.append(.studyEnrolled, detail: participantID, group: group)
    }

    // MARK: Settings

    func updateCooldown(_ settings: CooldownSettings) {
        state = SharedStore.update { $0.cooldown = settings }
    }
}
