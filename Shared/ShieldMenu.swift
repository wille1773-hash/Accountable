import Foundation

/// Session lengths offered right on the lock screen (iOS 26.4+ lets a shield show a short menu).
/// Longer or custom times are picked in the app.
enum ShieldMenu {
    static let minutes = [5, 15, 30]
}
