import DeviceActivity
import Foundation

/// iOS runs this in the background when a monitored schedule starts or ends,
/// or when usage of the selected apps crosses a threshold.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard let sessionID = activity.sessionID else { return }

        if event == .limit {
            SessionEngine.finish(sessionID: sessionID, reason: .limitReached)
        } else if let minutes = event.progressMinutes {
            SessionEngine.recordProgress(sessionID: sessionID, minutes: minutes)
        }
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        guard event == .limit, activity.sessionID != nil else { return }
        Notifier.post(id: "one-minute", title: "About a minute left", body: "Good time to wrap up.")
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        // A short session's minutes are up (see SessionEngine.startSitesClock).
        if activity.isSitesClock { blockSitesIfWanted() }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        SessionEngine.logLockoutEndIfNeeded()
        if activity.isSitesClock {
            blockSitesIfWanted()
            return
        }
        guard let sessionID = activity.sessionID else { return }
        // Restarting monitoring mid-session (the app list changed) may end the old interval early.
        // Only a window that has actually run out ends the session.
        if let session = SharedStore.load().session, session.id == sessionID,
           session.windowEnd > .now.addingTimeInterval(60) { return }
        SessionEngine.finish(sessionID: sessionID, reason: .windowEnded)
    }

    /// The session's minutes are up on the clock: social media websites block again.
    private func blockSitesIfWanted() {
        if SharedStore.load().blocksSocialSites { Shielding.filterSocialSites(true) }
    }
}
