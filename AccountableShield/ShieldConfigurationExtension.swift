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
        let copy = ShieldCopy.make(lockout: state.lockout, now: .now)

        // Study log: "app opened while locked". iOS may not let this extension write files, and it
        // may call this more than once per open or reuse an earlier result, so treat these counts
        // as approximate. Button taps (logged by the shield action extension) are reliable.
        EventLog.append(.shieldShown, detail: ShieldCopy.context(lockout: state.lockout, now: .now))

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: ShieldCopy.background,
            icon: UIImage(systemName: copy.symbol)?.withTintColor(ShieldCopy.accent, renderingMode: .alwaysOriginal),
            title: .init(text: copy.title, color: ShieldCopy.ink),
            subtitle: .init(text: copy.subtitle, color: ShieldCopy.secondary),
            primaryButtonLabel: .init(text: "Open Accountable", color: .white),
            primaryButtonBackgroundColor: ShieldCopy.accent,
            secondaryButtonLabel: .init(text: "Close", color: ShieldCopy.accent)
        )
    }
}

enum ShieldCopy {
    // Same palette as the app's Theme (extensions can't use the app's code or assets).
    static let accent = dynamic(light: 0xC96442, dark: 0xE08A66)
    static let background = dynamic(light: 0xFAF8F3, dark: 0x1C1B19)
    static let ink = dynamic(light: 0x22211E, dark: 0xF1EEE7)
    static let secondary = dynamic(light: 0x6B675F, dark: 0xA9A49A)

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
                subtitle: "You used the time you asked for. You can start again at \(time). See you then."
            )
        }
        return Text(
            symbol: "lock",
            title: "Resting for now",
            subtitle: "Open Accountable and say how long you want. We'll unlock it for exactly that long."
        )
    }
}
