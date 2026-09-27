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
        EventLog.append(.shieldShown, detail: ShieldCopy.context(lockout: state.lockout, now: .now), group: state.study.group)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: copy.symbol)?.withTintColor(ShieldCopy.accent, renderingMode: .alwaysOriginal),
            title: .init(text: copy.title, color: .label),
            subtitle: .init(text: copy.subtitle, color: .secondaryLabel),
            primaryButtonLabel: .init(text: "Open Accountable", color: .white),
            primaryButtonBackgroundColor: ShieldCopy.accent,
            secondaryButtonLabel: .init(text: "Close", color: ShieldCopy.accent)
        )
    }
}

enum ShieldCopy {
    /// Matches AccentColor in the app's asset catalog (extensions can't read the app's assets).
    static let accent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.333, green: 0.741, blue: 0.651, alpha: 1)
            : UIColor(red: 0.122, green: 0.478, blue: 0.420, alpha: 1)
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
                subtitle: "You used the time you asked for. You can start a new session at \(time)."
            )
        }
        return Text(
            symbol: "lock",
            title: "This one's locked",
            subtitle: "Open Accountable and say how long you want. We'll unlock it for exactly that long."
        )
    }
}
