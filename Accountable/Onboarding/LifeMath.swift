import Foundation

/// The lifetime projection shown in the intro.
///
/// - Years left come from the official US life table (CDC/NCHS, United States Life Tables, 2023,
///   Table 1, total population): the average remaining lifetime at your exact age. At 20 that's
///   59.2 years, which is more accurate than "life expectancy at birth minus your age".
/// - Time on social media is your daily minutes as a share of all 24 hours, applied to every
///   remaining year. So 2 hr 20 min a day is 9.7% of your time, and 9.7% of 59.2 years is 5.8 years.
/// - "So far" assumes the same daily time since age 13, the minimum age most platforms set.
struct LifeMath {
    static let startAge = 13
    static let daysPerYear = 365.25
    static let source = "CDC/NCHS, United States Life Tables, 2023"

    /// Average remaining years of life at exact ages 0...100 (the "ex" column), total US population, 2023.
    static let remainingYearsByAge: [Double] = [
        78.42, 77.86, 76.90, 75.92, 74.93, 73.94, 72.96, 71.97, 70.97, 69.98,
        68.99, 68.00, 67.00, 66.01, 65.03, 64.04, 63.07, 62.10, 61.14, 60.18,
        59.22, 58.27, 57.32, 56.38, 55.43, 54.49, 53.56, 52.62, 51.68, 50.75,
        49.82, 48.90, 47.98, 47.06, 46.14, 45.22, 44.31, 43.39, 42.48, 41.58,
        40.67, 39.77, 38.87, 37.97, 37.08, 36.18, 35.29, 34.40, 33.51, 32.63,
        31.76, 30.89, 30.02, 29.16, 28.31, 27.46, 26.63, 25.80, 24.98, 24.17,
        23.37, 22.59, 21.81, 21.04, 20.28, 19.52, 18.77, 18.03, 17.30, 16.58,
        15.86, 15.15, 14.45, 13.75, 13.07, 12.40, 11.75, 11.10, 10.48, 9.87,
        9.29, 8.72, 8.17, 7.64, 7.14, 6.65, 6.18, 5.74, 5.33, 4.94,
        4.58, 4.24, 3.93, 3.64, 3.38, 3.14, 2.91, 2.71, 2.53, 2.36,
        2.21,
    ]

    var dailyMinutes: Int
    var age: Int

    /// Share of all time (not just waking hours) spent on social media.
    var shareOfTime: Double { Double(dailyMinutes) / (24 * 60) }

    /// Average years of life left at this age.
    var yearsLeft: Double {
        let table = Self.remainingYearsByAge
        return table[min(max(age, 0), table.count - 1)]
    }

    /// Rounded, for "one dot per year".
    var wholeYearsLeft: Int { Int(yearsLeft.rounded()) }

    /// Years of the rest of your life spent on social media at this pace.
    var yearsAhead: Double { shareOfTime * yearsLeft }

    var yearsSoFar: Double { shareOfTime * Double(max(0, age - Self.startAge)) }
    var daysSoFar: Int { Int((yearsSoFar * Self.daysPerYear).rounded()) }

    /// Share of waking hours, assuming 16 waking hours a day.
    var shareOfWakingHours: Double { Double(dailyMinutes) / (16 * 60) }

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
