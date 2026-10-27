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
        // Read from Screen Time settings, since this extension can't read the saved state.
        let mode = LockScreenState.read()
        let copy = ShieldCopy.make(mode)
        let onBreak = if case .onBreak = mode { true } else { false }
        let inSession = if case .session = mode { true } else { false }
        // Match the app's Light, Dark or Auto setting (see ShieldAppearance).
        ShieldCopy.style = switch ShieldAppearance.current() {
        case .light: .light
        case .dark: .dark
        case nil: .unspecified
        }

        // Study log: "app opened while locked". iOS may call this more than once per open or reuse
        // an earlier result, so treat these counts as approximate. Just opening the app doesn't
        // break a promise; choosing "Unlock anyway" does.
        EventLog.append(.shieldShown, detail: ShieldCopy.context(mode))

        let icon = UIImage(systemName: copy.symbol)?.withTintColor(ShieldCopy.accent, renderingMode: .alwaysOriginal)
        let title = ShieldConfiguration.Label(text: copy.title, color: ShieldCopy.ink)
        let subtitle = ShieldConfiguration.Label(text: copy.subtitle, color: ShieldCopy.secondary)

        if inSession {
            // The session's time is shared: spend some of it here, or not.
            return ShieldConfiguration(
                backgroundBlurStyle: ShieldCopy.blur,
                backgroundColor: ShieldCopy.background.withAlphaComponent(0.55),
                icon: icon,
                title: title,
                subtitle: subtitle,
                primaryButtonLabel: .init(text: "Use it here", color: ShieldCopy.onAccent),
                primaryButtonBackgroundColor: ShieldCopy.accent,
                secondaryButtonLabel: .init(text: "Not now", color: ShieldCopy.accent)
            )
        }

        if #available(iOS 26.4, *) {
            // Pick a time right here. The big button is the good choice; the menu is a step away.
            return ShieldConfiguration(
                backgroundBlurStyle: ShieldCopy.blur,
                backgroundColor: ShieldCopy.background.withAlphaComponent(0.55),
                icon: icon,
                title: title,
                subtitle: subtitle,
                primaryButtonLabel: .init(text: onBreak ? "Keep my promise" : "Not now", color: ShieldCopy.onAccent),
                primaryButtonBackgroundColor: ShieldCopy.accent,
                secondaryButtonLabel: .init(text: onBreak ? "Unlock anyway…" : "Unlock for…", color: ShieldCopy.accent),
                secondaryButtonSubmenuItems: ShieldMenu.items.map(\.title)
            )
        }

        return ShieldConfiguration(
            backgroundBlurStyle: ShieldCopy.blur,
            backgroundColor: ShieldCopy.background.withAlphaComponent(0.55),
            icon: icon,
            title: title,
            subtitle: subtitle,
            primaryButtonLabel: .init(text: onBreak ? "Close" : "Open Accountable", color: ShieldCopy.onAccent),
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
    static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x0E1A13)

    /// Light or dark when the app's setting says so; unspecified follows the phone.
    static var style: UIUserInterfaceStyle = .unspecified

    static var blur: UIBlurEffect.Style {
        switch style {
        case .light: .systemThickMaterialLight
        case .dark: .systemThickMaterialDark
        default: .systemThickMaterial
        }
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            let isDark = style == .unspecified ? traits.userInterfaceStyle == .dark : style == .dark
            let hex = isDark ? dark : light
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

    /// "session" if a session is running, "cooldown" if a break is, otherwise "locked".
    static func context(_ mode: LockScreenState) -> String {
        switch mode {
        case .session: "session"
        case .onBreak: "cooldown"
        case .locked: "locked"
        }
    }

    static func make(_ mode: LockScreenState) -> Text {
        switch mode {
        case .session(let left):
            return Text(
                symbol: "timer",
                title: "About \(left) min left",
                subtitle: "Your timer is shared across your apps. Spend some of it here?"
            )
        case .onBreak(let until):
            let time = until.formatted(date: .omitted, time: .shortened)
            return Text(
                symbol: "hourglass",
                title: "Taking a breather",
                subtitle: "You kept your word. Back at \(time). Unlocking before then breaks your promise, and Buddy will be sad."
            )
        case .locked:
            return Text(
                symbol: "lock",
                title: "Resting for now",
                subtitle: "How long do you want? Say it and mean it. It locks again when the time's up."
            )
        }
    }
}
