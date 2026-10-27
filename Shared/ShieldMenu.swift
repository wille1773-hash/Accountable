import Foundation

/// The menu under the lock screen's second button (iOS 26.4+ allows up to three items).
/// Two quick times, plus "Custom time…", which opens Accountable to the time picker.
enum ShieldMenu {
    enum Item: Equatable {
        case minutes(Int)
        case custom

        var title: String {
            switch self {
            case .minutes(let m): "\(m) minutes"
            case .custom: "Custom time…"
            }
        }
    }

    static let items: [Item] = [.minutes(5), .minutes(15), .custom]
}
