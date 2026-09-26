import FamilyControls
import ManagedSettings

extension ManagedSettingsStore.Name {
    static let accountable = Self("accountable")
}

/// Puts the lock screen ("shield") over the selected apps, or takes it off.
/// The app and the extensions all use the same named store, so a lock set by one
/// can be lifted by another.
enum Shielding {
    private static var store: ManagedSettingsStore { ManagedSettingsStore(named: .accountable) }

    static func lock(_ selection: FamilyActivitySelection) {
        let store = store
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    }

    static func unlock() {
        let store = store
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }
}
