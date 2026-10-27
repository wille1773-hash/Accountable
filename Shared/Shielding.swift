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
        // Clear first: iOS keeps showing a saved lock screen until the shield settings change,
        // and this makes it ask for the current one (for example "Use it here" during a session).
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
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

/// The app's Light, Dark or Auto choice, passed to the lock screen. The lock screen extension can't
/// read Accountable's saved data, but it can read Screen Time settings. So the choice is kept as a
/// setting that changes nothing, "in-app purchases allowed", in a store named after it. An "allowed"
/// never overrides a stricter setting from anywhere else, so the phone behaves exactly the same.
enum ShieldAppearance {
    enum Choice: String, CaseIterable {
        case light, dark
    }

    private static func store(_ choice: Choice) -> ManagedSettingsStore {
        ManagedSettingsStore(named: .init("appearance.\(choice.rawValue)"))
    }

    /// Nil means follow the phone.
    static func set(_ choice: Choice?) {
        for option in Choice.allCases {
            let store = store(option)
            let wanted: Bool? = option == choice ? false : nil
            if store.appStore.denyInAppPurchases != wanted { store.appStore.denyInAppPurchases = wanted }
        }
    }

    static func current() -> Choice? {
        Choice.allCases.first { store($0).appStore.denyInAppPurchases != nil }
    }
}
