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

    /// Locks the selected apps, except anything opened for the running session.
    static func lock(_ selection: FamilyActivitySelection, except opened: Opened = Opened()) {
        let store = store
        let apps = selection.applicationTokens.subtracting(opened.applications)
        let sites = selection.webDomainTokens.subtracting(opened.webDomains)
        let categories = selection.categoryTokens.subtracting(opened.categories)
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories, except: opened.applications)
        store.shield.webDomains = sites.isEmpty ? nil : sites
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories, except: opened.webDomains)
    }

    /// Removes every setting Accountable has applied.
    static func clearAll() {
        store.clearAllSettings()
    }
}
