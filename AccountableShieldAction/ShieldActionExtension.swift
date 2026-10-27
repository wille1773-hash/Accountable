import ManagedSettings

/// Handles taps on the lock screen's buttons.
///
/// On iOS 26.5 and later, "Open Accountable" opens the app directly. Earlier versions can't open
/// apps from here, so we send a notification the user can tap instead, then close the locked app.
///
/// Unlocking opens only the app the lock screen is on. During a session, other apps show
/// "Use it here", which spends the same time on them.
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action, opening: Opened(applications: [application])))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action, opening: Opened(webDomains: [webDomain])))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action, opening: Opened(categories: [category])))
    }

    private func respond(to action: ShieldAction, opening: Opened) -> ShieldActionResponse {
        let state = SharedStore.load()
        let onBreak = (state.lockout?.endsAt ?? .distantPast) > .now
        let context = onBreak ? "cooldown" : "locked"

        // A session is running: the big button is "Use it here". iOS sometimes shows an out-of-date
        // lock screen, so a time from the old menu means the same thing.
        if let session = state.session, session.windowEnd > .now {
            let unlocks = action == .primaryButtonPressed || menuItem(for: action) != nil
            EventLog.append(.shieldButtonTapped, detail: unlocks ? "use_here,session" : "not_now,session")
            guard unlocks, SessionEngine.open(opening) else { return .close }
            return .none
        }

        // iOS 26.4+: the "Unlock for…" / "Unlock anyway…" menu.
        if let item = menuItem(for: action) {
            switch item {
            case .minutes(let minutes):
                EventLog.append(.shieldButtonTapped, detail: "unlock_\(minutes),\(context)")
                EventLog.append(.sessionRequested, minutes: minutes, detail: "lock_screen")
                do {
                    // During a break this ends the break and breaks the promise; the menu said so.
                    try SessionEngine.start(minutes: minutes, breakingPromise: onBreak, opening: opening)
                    // The lock lifts as soon as the session starts, so the app just carries on.
                    return .none
                } catch {
                    EventLog.append(.sessionStartFailed, minutes: minutes, detail: String(describing: error))
                    return .close
                }
            case .custom:
                EventLog.append(.shieldButtonTapped, detail: "custom,\(context)")
                SharedStore.update { $0.wantsCustomTime = true }
                return openAccountable(note: "Tap here to pick your time.")
            }
        }

        let button = action == .primaryButtonPressed ? "primary" : "secondary"
        EventLog.append(.shieldButtonTapped, detail: "\(button),\(context)")

        // Before iOS 26.4 there's no menu: one button opens Accountable (see ShieldConfigurationExtension).
        if #available(iOS 26.4, *) { return .close }
        let opensApp = onBreak ? action == .secondaryButtonPressed : action == .primaryButtonPressed
        return opensApp ? openAccountable(note: "Tap here to open Accountable and say how long you want.") : .close
    }

    private func openAccountable(note: String) -> ShieldActionResponse {
        if #available(iOS 26.5, *) {
            return .openParentalControlsApp
        }
        Notifier.post(id: "open-accountable", title: "Accountable", body: note)
        return .close
    }

    private func menuItem(for action: ShieldAction) -> ShieldMenu.Item? {
        guard #available(iOS 26.4, *) else { return nil }
        let index: Int
        switch action {
        case .firstSecondarySubmenuItemPressed: index = 0
        case .secondSecondarySubmenuItemPressed: index = 1
        case .thirdSecondarySubmenuItemPressed: index = 2
        default: return nil
        }
        return ShieldMenu.items.indices.contains(index) ? ShieldMenu.items[index] : nil
    }
}
