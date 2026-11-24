import Foundation

/// Decides which curated entry is "today's word" without needing any server
/// or sync: it's a pure function of the date, the word list and which words
/// you've already been introduced to.
enum Rotation {
    /// FNV-1a: a tiny, *stable* hash. Swift's `hashValue` is randomized per
    /// launch, so it can't be used for an order that must match across devices.
    static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    /// Curated entries in a fixed pseudo-random order, so categories interleave
    /// and adding new entries to the JSON files just slots them in somewhere.
    static func order(_ ids: [String]) -> [String] {
        ids.sorted { (stableHash($0), $0) < (stableHash($1), $1) }
    }

    /// Whole days since a fixed epoch, in the user's calendar.
    static func dayIndex(for date: Date, calendar: Calendar = .current) -> Int {
        let epoch = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date(timeIntervalSince1970: 0)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: epoch), to: calendar.startOfDay(for: date)).day ?? 0
        return days
    }

    /// Picks today's entry: start at a date-based offset in the ordered list and
    /// take the first entry that wasn't introduced on an *earlier* day.
    ///
    /// Words introduced *today* are deliberately not skipped. If your Mac already
    /// introduced today's word and that synced to your iPhone, the iPhone must
    /// land on the same word rather than move on to the next one.
    static func pickDaily(orderedIDs: [String], dayIndex: Int, introducedBeforeToday: Set<String>) -> String? {
        guard !orderedIDs.isEmpty else { return nil }
        let count = orderedIDs.count
        let start = ((dayIndex % count) + count) % count
        for step in 0..<count {
            let id = orderedIDs[(start + step) % count]
            if !introducedBeforeToday.contains(id) { return id }
        }
        // Everything has been introduced: just cycle through again.
        return orderedIDs[start]
    }
}
