import SwiftUI

/// Warm and minimal: ivory paper, ink text, one terracotta accent, serif headlines, lots of room.
enum Theme {
    static let background = Color(light: 0xFAF8F3, dark: 0x1C1B19)
    static let card = Color(light: 0xF1ECE2, dark: 0x282623)
    static let ink = Color(light: 0x22211E, dark: 0xF1EEE7)
    static let secondaryText = Color(light: 0x6B675F, dark: 0xA9A49A)
    static let hairline = Color(light: 0xE4DDD0, dark: 0x3A3733)
    static let accent = Color(light: 0xC96442, dark: 0xE08A66)
    /// Soft tint of the accent for fills behind accent content.
    static let accentSoft = Color(light: 0xF3DDD2, dark: 0x3F2B22)
    /// Muted fill for "past" or inactive things, e.g. years already lived.
    static let muted = Color(light: 0xD9D2C5, dark: 0x45413B)

    // Type
    static func display(_ size: CGFloat = 34) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func title(_ size: CGFloat = 24) -> Font { .system(size: size, weight: .medium, design: .serif) }
    static func bigNumber(_ size: CGFloat = 64) -> Font {
        .system(size: size, weight: .medium, design: .serif).monospacedDigit()
    }
    static let body = Font.system(.body)
    static let label = Font.system(.subheadline, weight: .medium)

    static let corner: CGFloat = 22
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.85)
}

extension Color {
    /// A color that switches between light and dark mode. Hex like 0xC96442.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: Components

struct Card<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }
}

/// Small caps label above a section, e.g. "TODAY".
struct Eyebrow: View {
    var text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.secondaryText)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(Color(light: 0xFFFFFF, dark: 0x1C1B19))
            .background(Theme.ink.opacity(isEnabled ? 1 : 0.25),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct AccentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(.white)
            .background(Theme.accent.opacity(isEnabled ? 1 : 0.35),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, weight: .medium))
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == AccentButtonStyle {
    static var accent: AccentButtonStyle { AccentButtonStyle() }
}

extension ButtonStyle where Self == QuietButtonStyle {
    static var quiet: QuietButtonStyle { QuietButtonStyle() }
}

/// Screen scaffold: ivory background and comfortable side margins.
struct Screen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.background.ignoresSafeArea())
    }
}
