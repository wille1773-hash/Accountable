import FamilyControls
import Foundation
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
        // Where photos and videos come from. Blocking these stops a page that was already open
        // when time ran out from loading anything new.
        "cdninstagram.com", "fbcdn.net", "googlevideo.com", "ytimg.com", "i.ytimg.com",
        "tiktokcdn.com", "tiktokv.com", "redd.it", "i.redd.it", "v.redd.it", "sc-cdn.net",
    ]

    /// Turns the social media website block on or off.
    static func filterSocialSites(_ on: Bool) {
        store.webContent.blockedByFilter = on ? .specific(Set(socialSites.map { WebDomain(domain: $0) })) : nil
    }

    /// Briefly hides the selected apps, which closes any that are open, then brings them back.
    /// Apps like SocialLite can't be locked, and a page they already have open keeps working after
    /// the website block comes back. Closing them means the next open loads fresh and gets blocked.
    static func closeApps(_ selection: FamilyActivitySelection) {
        let apps = Set(selection.applicationTokens.map { Application(token: $0) })
        guard !apps.isEmpty else { return }
        store.application.blockedApplications = apps
        Thread.sleep(forTimeInterval: 2)
        store.application.blockedApplications = nil
    }

    /// Brings back any apps `closeApps` hid, in case it was stopped partway through.
    static func unhideApps() {
        if store.application.blockedApplications != nil { store.application.blockedApplications = nil }
    }

    /// Removes every setting Accountable has applied.
    static func clearAll() {
        store.clearAllSettings()
    }
}
