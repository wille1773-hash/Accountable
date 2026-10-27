import ManagedSettings

/// Handles taps on the lock screen's buttons.
///
/// On iOS 26.5 and later, "Open Accountable" opens the app directly. Earlier versions can't open
/// apps from here, so we send a notification the user can tap instead, then close the locked app.
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    private func respond(to action: ShieldAction) -> ShieldActionResponse {
        let state = SharedStore.load()
        let onBreak = (state.lockout?.endsAt ?? .distantPast) > .now
        let context = onBreak ? "cooldown" : "locked"

        // iOS 26.4+: a time picked from the lock screen's "Unlock for…" menu starts a session here.
        if let minutes = menuMinutes(for: action), !onBreak {
            EventLog.append(.shieldButtonTapped, detail: "unlock_\(minutes),\(context)")
            EventLog.append(.sessionRequested, minutes: minutes, detail: "lock_screen")
            do {
                try SessionEngine.start(minutes: minutes)
                // The lock lifts as soon as the session starts, so the app just carries on.
                return .none
            } catch {
                EventLog.append(.sessionStartFailed, minutes: minutes, detail: String(describing: error))
                return .close
            }
        }

        let button = action == .primaryButtonPressed ? "primary" : "secondary"
        EventLog.append(.shieldButtonTapped, detail: "\(button),\(context)")

        // Which button opens Accountable depends on the layout (see ShieldConfigurationExtension).
        let opensApp: Bool
        if #available(iOS 26.4, *), !onBreak {
            opensApp = false  // "Not now" and the menu; there's no Open button in this layout
        } else {
            opensApp = onBreak ? action == .secondaryButtonPressed : action == .primaryButtonPressed
        }
        guard opensApp else { return .close }
        if #available(iOS 26.5, *) {
            return .openParentalControlsApp
        }
        Notifier.post(id: "open-accountable", title: "Accountable", body: "Tap here to open Accountable and say how long you want.")
        return .close
    }

    private func menuMinutes(for action: ShieldAction) -> Int? {
        guard #available(iOS 26.4, *) else { return nil }
        let index: Int
        switch action {
        case .firstSecondarySubmenuItemPressed: index = 0
        case .secondSecondarySubmenuItemPressed: index = 1
        case .thirdSecondarySubmenuItemPressed: index = 2
        default: return nil
        }
        return ShieldMenu.minutes.indices.contains(index) ? ShieldMenu.minutes[index] : nil
    }
}
