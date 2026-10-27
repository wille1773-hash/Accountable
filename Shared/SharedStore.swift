import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Reads and writes `SharedState`, shared by the app and its extensions through `SharedKeychain`.
///
/// The app and the extensions run as separate processes. Each read-modify-write is short and
/// happens under a lock within a process; writes from two processes at the same instant (rare:
/// e.g. the monitor ending a session while the app is open) resolve as last writer wins.
enum SharedStore {
    private static let key = "state"

    static func load() -> SharedState {
        SharedKeychain.lock.lock(); defer { SharedKeychain.lock.unlock() }
        return read()
    }

    /// Applies `change` to the latest saved state and saves it. Returns the new state.
    @discardableResult
    static func update(_ change: (inout SharedState) -> Void) -> SharedState {
        SharedKeychain.lock.lock()
        var state = read()
        change(&state)
        if let data = try? JSONEncoder().encode(state) {
            SharedKeychain.write(data, for: key)
        }
        SharedKeychain.lock.unlock()
        // Tell the lock screen, which can't read this (see LockScreenState). Widgets can't change
        // Screen Time settings and never change the session or break anyway.
        if Bundle.main.bundleIdentifier?.hasSuffix(".Widget") != true { LockScreenState.publish(state) }
        #if canImport(WidgetKit)
        // Keep Buddy's widgets in step with the app.
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        return state
    }

    private static func read() -> SharedState {
        guard let data = SharedKeychain.read(key),
              let state = try? JSONDecoder().decode(SharedState.self, from: data) else {
            return SharedState()
        }
        return state
    }
}
