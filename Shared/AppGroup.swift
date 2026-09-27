import Foundation

/// The App Group is a folder on disk that the app and all three extensions can read and write.
/// Everything the extensions need to know (selected apps, current session, cooldowns) lives here.
enum AppGroup {
    static let id = "group.com.wille1773.accountable"

    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
            return url
        }
        // Only happens if the App Group capability is missing from a target's signing setup.
        // Keep running with temporary storage rather than crashing; data won't be shared.
        print("⚠️ App Group \(id) is not configured for this target. Using temporary storage.")
        return FileManager.default.temporaryDirectory
    }

    static func fileURL(_ name: String) -> URL {
        containerURL.appendingPathComponent(name)
    }
}
