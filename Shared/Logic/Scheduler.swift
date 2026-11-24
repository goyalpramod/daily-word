import Foundation

/// Spaced-repetition scheduling: a simplified SM-2.
///
/// Every correct answer pushes the next review further out (3 days, then 7, then
/// interval × ease). A miss brings the word back tomorrow and makes it slightly
/// "harder" (lower ease), so words you struggle with come back more often.
enum Scheduler {
    enum Grade { case correct, missed }

    struct State: Equatable {
        var intervalDays: Int = 0
        var ease: Double = 2.5
        var streak: Int = 0
    }

    static let minEase = 1.3
    static let maxEase = 2.8
    static let maxIntervalDays = 365

    static func next(_ state: State, grade: Grade) -> State {
        var s = state
        switch grade {
        case .missed:
            s.streak = 0
            s.intervalDays = 1
            s.ease = max(minEase, s.ease - 0.2)
        case .correct:
            s.streak += 1
            switch s.streak {
            case 1: s.intervalDays = 3
            case 2: s.intervalDays = 7
            default: s.intervalDays = Int((Double(max(s.intervalDays, 1)) * s.ease).rounded())
            }
            s.intervalDays = min(s.intervalDays, maxIntervalDays)
            s.ease = min(maxEase, s.ease + 0.05)
        }
        return s
    }

    /// Reviews become due at the start of a day, so a word scheduled "in 3 days"
    /// shows up at midnight rather than at the exact time you last answered.
    static func dueDate(afterDays days: Int, from date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: days, to: start) ?? start
    }

    /// A rough 0...1 "how well do I know this" for the UI.
    static func strength(streak: Int, intervalDays: Int) -> Double {
        guard streak > 0 else { return 0 }
        return min(1, log2(Double(intervalDays) + 1) / log2(Double(60)))
    }
}
