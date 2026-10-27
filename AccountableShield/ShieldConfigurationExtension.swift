import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws the screen that covers a locked app.
///
/// iOS asks for this each time the shield is about to appear. It is a static screen: it can't
/// tick down, so during a cooldown it shows the clock time the user can start again.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        let state = SharedStore.load()
        let now = Date.now
        let onBreak = (state.lockout?.endsAt ?? .distantPast) > now
        let copy = ShieldCopy.make(lockout: state.lockout, now: now)

        // Study log: "app opened while locked". iOS may call this more than once per open or reuse
        // an earlier result, so treat these counts as approximate.
        EventLog.append(.shieldShown, detail: ShieldCopy.context(lockout: state.lockout, now: now))
        // Opening a locked app during a break breaks the promise from the session before it.
        if onBreak { SessionEngine.recordBreakAttempt(now: now) }

        let icon = UIImage(systemName: copy.symbol)?.withTintColor(ShieldCopy.accent, renderingMode: .alwaysOriginal)
        let title = ShieldConfiguration.Label(text: copy.title, color: ShieldCopy.ink)
        let subtitle = ShieldConfiguration.Label(text: copy.subtitle, color: ShieldCopy.secondary)

        if #available(iOS 26.4, *), !onBreak {
            // Pick a time right here: "Not now" is the big button, "Unlock for…" opens a short menu.
            return ShieldConfiguration(
                backgroundBlurStyle: nil,
                backgroundColor: ShieldCopy.background,
                icon: icon,
                title: title,
                subtitle: .init(text: "How long do you want? Say it and mean it. It locks again when the time's up.", color: ShieldCopy.secondary),
                primaryButtonLabel: .init(text: "Not now", color: .white),
                primaryButtonBackgroundColor: ShieldCopy.accent,
                secondaryButtonLabel: .init(text: "Unlock for…", color: ShieldCopy.accent),
                secondaryButtonSubmenuItems: ShieldMenu.minutes.map { "\($0) minutes" }
            )
        }

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: ShieldCopy.background,
            icon: icon,
            title: title,
            subtitle: subtitle,
            primaryButtonLabel: .init(text: onBreak ? "Close" : "Open Accountable", color: .white),
            primaryButtonBackgroundColor: ShieldCopy.accent,
            secondaryButtonLabel: .init(text: onBreak ? "Open Accountable" : "Close", color: ShieldCopy.accent)
        )
    }
}

enum ShieldCopy {
    // Same palette as the app's Theme (extensions can't use the app's code or assets).
    static let accent = dynamic(light: 0x2F7A58, dark: 0x6CC79A)
    static let background = dynamic(light: 0xF6F7F3, dark: 0x141916)
    static let ink = dynamic(light: 0x1C2420, dark: 0xEEF2EC)
    static let secondary = dynamic(light: 0x5C6862, dark: 0x9AA69F)

    private static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }
    }

    struct Text {
        var symbol: String
        var title: String
        var subtitle: String
    }

    /// "cooldown" if a break is running, otherwise "locked".
    static func context(lockout: Lockout?, now: Date) -> String {
        if let lockout, lockout.endsAt > now { return "cooldown" }
        return "locked"
    }

    static func make(lockout: Lockout?, now: Date) -> Text {
        if let lockout, lockout.endsAt > now {
            let time = lockout.endsAt.formatted(date: .omitted, time: .shortened)
            return Text(
                symbol: "hourglass",
                title: "Taking a breather",
                subtitle: "You kept your word. Back at \(time). Coming back before then breaks the promise, and Buddy notices."
            )
        }
        return Text(
            symbol: "lock",
            title: "Resting for now",
            subtitle: "Open Accountable and say how long you want. We'll unlock it for exactly that long."
        )
    }
}
