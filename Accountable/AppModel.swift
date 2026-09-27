import Combine
import FamilyControls
import Foundation

/// The app's view of the shared state, plus the actions the UI can take.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state = SharedStore.load()
    @Published private(set) var authorizationStatus = AuthorizationCenter.shared.authorizationStatus

    private var cancellables = Set<AnyCancellable>()

    init() {
        AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in self?.authorizationStatus = status }
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
        SessionEngine.logLockoutEndIfNeeded()
        state = SharedStore.load()
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
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
        state = SharedStore.update { state in
            state.selection = selection
            state.hasCompletedSetup = true
            if state.firstDay == nil { state.firstDay = DayKey.string(for: .now) }
        }
        reassertLock()
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
