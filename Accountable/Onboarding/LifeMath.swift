import Foundation

/// The lifetime projection shown in the intro.
///
/// Assumptions (shown to the user): the same daily time every day, social media from age 13
/// (the minimum age most platforms set), and living to 79, about the US average life expectancy.
struct LifeMath {
    static let startAge = 13
    static let lifeExpectancy = 79
    static let wakingHoursPerDay = 16.0

    var dailyMinutes: Int
    var age: Int

    private var dailyFractionOfLife: Double { Double(dailyMinutes) / (24 * 60) }

    var yearsSoFar: Double { dailyFractionOfLife * Double(max(0, age - Self.startAge)) }
    var daysSoFar: Int { Int((yearsSoFar * 365).rounded()) }
    var yearsAhead: Double { dailyFractionOfLife * Double(max(0, Self.lifeExpectancy - age)) }
    /// Share of waking hours, e.g. 0.15 for 2h 24m a day.
    var shareOfWakingHours: Double { Double(dailyMinutes) / 60 / Self.wakingHoursPerDay }

    /// Years won back over the rest of your life by cutting `minutes` a day.
    func yearsBack(cuttingMinutes minutes: Int) -> Double {
        Double(min(minutes, dailyMinutes)) / (24 * 60) * Double(max(0, Self.lifeExpectancy - age))
    }

    static func format(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m) min"
        case (_, 0): return "\(h) hr"
        default: return "\(h) hr \(m) min"
        }
    }

    static func format(years: Double) -> String {
        years < 10 ? String(format: "%.1f", years) : String(Int(years.rounded()))
    }
}
