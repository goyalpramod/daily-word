import Foundation
import SwiftData

// These models sync through iCloud (CloudKit). CloudKit has rules that shape them:
// every property needs a default value, and unique constraints aren't allowed.
// That's why duplicates are cleaned up in code (see Vocab.state(for:)) rather
// than prevented by the database.

/// Your learning progress for one entry (curated or custom).
@Model
final class ReviewState {
    var entryID: String = ""
    var introducedOn: Date = Date.now
    var dueDate: Date = Date.now
    var intervalDays: Int = 0
    var ease: Double = 2.5
    var streak: Int = 0
    var timesCorrect: Int = 0
    var timesWrong: Int = 0
    var lastReviewed: Date?

    init(entryID: String, introducedOn: Date, dueDate: Date) {
        self.entryID = entryID
        self.introducedOn = introducedOn
        self.dueDate = dueDate
    }

    var schedulerState: Scheduler.State {
        get { .init(intervalDays: intervalDays, ease: ease, streak: streak) }
        set {
            intervalDays = newValue.intervalDays
            ease = newValue.ease
            streak = newValue.streak
        }
    }

    var strength: Double { Scheduler.strength(streak: streak, intervalDays: intervalDays) }
}

/// A word or phrase you added yourself. The full `Entry` is stored as JSON so
/// the schema can evolve without SwiftData/CloudKit migrations.
@Model
final class CustomEntry {
    var entryID: String = ""
    var term: String = ""
    var createdAt: Date = Date.now
    var payload: Data = Data()

    init(entry: Entry) {
        self.entryID = entry.id
        self.term = entry.term
        self.payload = (try? JSONEncoder().encode(entry)) ?? Data()
    }

    var entry: Entry? { try? JSONDecoder().decode(Entry.self, from: payload) }

    func update(with entry: Entry) {
        term = entry.term
        payload = (try? JSONEncoder().encode(entry)) ?? payload
    }
}
