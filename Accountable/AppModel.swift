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
    }

    var isAuthorized: Bool { authorizationStatus == .approved }

    /// Re-reads the shared file, picking up anything the extensions changed while the app was closed.
    func refresh() {
        state = SharedStore.load()
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        reassertLock()
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
}
