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

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard let sessionID = activity.sessionID else { return }
        SessionEngine.finish(sessionID: sessionID, reason: .windowEnded)
    }
}
