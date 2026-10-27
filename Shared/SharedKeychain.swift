import Foundation
import Security

/// Storage shared by the app and all its extensions, kept in the keychain.
///
/// Every target lists the same keychain access group first in its entitlements
/// (`$(AppIdentifierPrefix)com.wille1773.accountable.shared`), so items saved here without naming a
/// group land in that shared group and every target can read them.
///
/// This replaces an App Group. The team's App Store Connect API key can't manage App Groups
/// (Apple answers 401), while a team-prefixed keychain group needs no setup on the developer site.
enum SharedKeychain {
    private static let service = "com.wille1773.accountable.shared"
    /// Serializes read-modify-write cycles inside one process.
    static let lock = NSRecursiveLock()

    static func read(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func write(_ data: Data, for key: String) {
        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemUpdate(match as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard status == errSecItemNotFound else {
            if status != errSecSuccess { print("⚠️ Shared keychain update failed (\(status)) for \(key)") }
            return
        }
        var add = match
        add[kSecValueData as String] = data
        // Readable in the background once the phone has been unlocked after a restart, which the
        // monitor extension needs when it re-locks apps.
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        if addStatus != errSecSuccess { print("⚠️ Shared keychain add failed (\(addStatus)) for \(key)") }
    }
}
