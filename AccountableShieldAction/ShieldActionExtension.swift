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
        let context = (state.lockout.map { $0.endsAt > .now } ?? false) ? "cooldown" : "locked"
        let button = action == .primaryButtonPressed ? "open_accountable" : "close"
        EventLog.append(.shieldButtonTapped, detail: "\(button),\(context)", group: state.study.group)

        switch action {
        case .primaryButtonPressed:
            if #available(iOS 26.5, *) {
                return .openParentalControlsApp
            }
            Notifier.post(id: "open-accountable", title: "Accountable", body: "Tap here to open Accountable and say how long you want.")
            return .close
        case .secondaryButtonPressed:
            return .close
        default:
            return .close
        }
    }
}
