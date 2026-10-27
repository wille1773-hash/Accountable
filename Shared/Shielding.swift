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

    /// Sites blocked by `filterSocialSites`. The filter is Apple's web content filter, so it applies
    /// to web pages in every app, not just Safari.
    static let socialSites = [
        "instagram.com", "www.instagram.com",
        "youtube.com", "www.youtube.com", "m.youtube.com",
        "tiktok.com", "www.tiktok.com", "m.tiktok.com",
        "facebook.com", "www.facebook.com", "m.facebook.com",
        "x.com", "twitter.com", "mobile.twitter.com",
        "reddit.com", "www.reddit.com",
        "snapchat.com", "www.snapchat.com",
        "threads.net", "www.threads.net", "threads.com", "www.threads.com",
    ]

    /// Turns the social media website block on or off.
    static func filterSocialSites(_ on: Bool) {
        store.webContent.blockedByFilter = on ? .specific(Set(socialSites.map { WebDomain(domain: $0) })) : nil
    }

    /// Removes every setting Accountable has applied.
    static func clearAll() {
        store.clearAllSettings()
    }
}
