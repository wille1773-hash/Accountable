import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Reads and writes `SharedState` to the App Group.
///
/// The app and the extensions run as separate processes and can touch this file at the same
/// moment (for example, the monitor extension ending a session while the app is open).
/// `NSFileCoordinator` makes each read-modify-write happen one at a time.
enum SharedStore {
    private static var url: URL { AppGroup.fileURL("state.json") }

    static func load() -> SharedState {
        var result = SharedState()
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
            result = read(readURL)
        }
        return result
    }

    /// Applies `change` to the latest saved state and saves it. Returns the new state.
    @discardableResult
    static func update(_ change: (inout SharedState) -> Void) -> SharedState {
        var result = SharedState()
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { writeURL in
            var state = read(writeURL)
            change(&state)
            if let data = try? JSONEncoder().encode(state) {
                try? data.write(to: writeURL, options: .atomic)
            }
            result = state
        }
        #if canImport(WidgetKit)
        // Keep Buddy's widgets in step with the app.
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        return result
    }

    private static func read(_ url: URL) -> SharedState {
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(SharedState.self, from: data) else {
            return SharedState()
        }
        return state
    }
}
