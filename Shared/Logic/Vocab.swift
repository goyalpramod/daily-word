import Foundation
import SwiftData
import WidgetKit

/// The app's core operations, shared by the app, the widget and the widget's buttons.
/// Every function takes a `ModelContext` so callers decide which thread/context to use.
enum Vocab {
    private static let dailyPickKey = "dailyPick"         // "<dayIndex>|<entryID>"
    private static let revealedKey = "revealedQuizID"     // widget flashcard flipped?

    // MARK: - Looking things up

    static func entry(id: String, in context: ModelContext) -> Entry? {
        if let curated = WordLibrary.shared.byID[id] { return curated }
        return customEntry(id: id, in: context)?.entry
    }

    static func customEntry(id: String, in context: ModelContext) -> CustomEntry? {
        var descriptor = FetchDescriptor<CustomEntry>(predicate: #Predicate { $0.entryID == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func customEntries(in context: ModelContext) -> [Entry] {
        let descriptor = FetchDescriptor<CustomEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        var seen = Set<String>()
        return ((try? context.fetch(descriptor)) ?? []).compactMap { custom in
            guard seen.insert(custom.entryID).inserted else { return nil }
            return custom.entry
        }
    }

    /// Progress for every entry you've met, keyed by entry ID.
    ///
    /// If two devices introduced the same word before syncing, iCloud ends up
    /// with two records for it. We keep the one with more history and delete
    /// the other, so duplicates heal themselves the next time this runs.
    static func allStates(in context: ModelContext) -> [String: ReviewState] {
        let all = (try? context.fetch(FetchDescriptor<ReviewState>())) ?? []
        var result: [String: ReviewState] = [:]
        var removedDuplicates = false
        for state in all {
            guard let existing = result[state.entryID] else {
                result[state.entryID] = state
                continue
            }
            let keepNew = (state.timesCorrect + state.timesWrong, state.lastReviewed ?? .distantPast)
                > (existing.timesCorrect + existing.timesWrong, existing.lastReviewed ?? .distantPast)
            let (keep, drop) = keepNew ? (state, existing) : (existing, state)
            keep.introducedOn = min(keep.introducedOn, drop.introducedOn)
            context.delete(drop)
            result[state.entryID] = keep
            removedDuplicates = true
        }
        if removedDuplicates { try? context.save() }
        return result
    }

    static func state(for id: String, in context: ModelContext) -> ReviewState? {
        allStates(in: context)[id]
    }

    // MARK: - Today's word

    static func todaysEntry(in context: ModelContext, now: Date = .now) -> Entry? {
        let library = WordLibrary.shared
        let day = Rotation.dayIndex(for: now)

        if let stored = SharedConfig.defaults.string(forKey: dailyPickKey) {
            let parts = stored.split(separator: "|", maxSplits: 1).map(String.init)
            if parts.count == 2, Int(parts[0]) == day, let entry = library.byID[parts[1]] {
                introduce(id: entry.id, in: context, now: now)
                return entry
            }
        }

        let startOfToday = Calendar.current.startOfDay(for: now)
        let introducedBefore = Set(allStates(in: context).values
            .filter { $0.introducedOn < startOfToday }
            .map(\.entryID))
        guard let id = Rotation.pickDaily(orderedIDs: library.rotation, dayIndex: day, introducedBeforeToday: introducedBefore),
              let entry = library.byID[id] else { return nil }

        SharedConfig.defaults.set("\(day)|\(id)", forKey: dailyPickKey)
        introduce(id: id, in: context, now: now)
        return entry
    }

    /// Adds an entry to your review deck; its first quiz is tomorrow.
    static func introduce(id: String, in context: ModelContext, now: Date = .now) {
        guard state(for: id, in: context) == nil else { return }
        context.insert(ReviewState(entryID: id, introducedOn: now, dueDate: Scheduler.dueDate(afterDays: 1, from: now)))
        try? context.save()
    }

    // MARK: - Reviews

    /// Entries due for review, most overdue first. Today's new word is left out:
    /// you only just learned it.
    static func dueEntries(in context: ModelContext, now: Date = .now, excluding excludedID: String? = nil) -> [Entry] {
        allStates(in: context).values
            .filter { $0.dueDate <= now && $0.entryID != excludedID }
            .sorted { ($0.dueDate, Rotation.stableHash($0.entryID)) < ($1.dueDate, Rotation.stableHash($1.entryID)) }
            .compactMap { entry(id: $0.entryID, in: context) }
    }

    static func nextDueDate(in context: ModelContext, now: Date = .now) -> Date? {
        allStates(in: context).values.map(\.dueDate).filter { $0 > now }.min()
    }

    static func grade(id: String, _ grade: Scheduler.Grade, in context: ModelContext, now: Date = .now) {
        guard let state = state(for: id, in: context) else { return }
        state.schedulerState = Scheduler.next(state.schedulerState, grade: grade)
        state.dueDate = Scheduler.dueDate(afterDays: state.intervalDays, from: now)
        state.lastReviewed = now
        switch grade {
        case .correct: state.timesCorrect += 1
        case .missed: state.timesWrong += 1
        }
        try? context.save()
        if SharedConfig.defaults.string(forKey: revealedKey) == id {
            SharedConfig.defaults.removeObject(forKey: revealedKey)
        }
        reloadWidgets()
    }

    // MARK: - Widget flashcard state

    static func isRevealed(_ id: String) -> Bool {
        SharedConfig.defaults.string(forKey: revealedKey) == id
    }

    static func setRevealed(_ id: String?) {
        SharedConfig.defaults.set(id, forKey: revealedKey)
    }

    // MARK: - Your own words

    /// Saves (or updates) a word you added and puts it in your review deck.
    @discardableResult
    static func saveCustom(_ draft: Entry, in context: ModelContext, now: Date = .now) -> Entry {
        var entry = draft
        entry.category = Entry.customCategory
        if entry.id.isEmpty || !entry.id.hasPrefix("my-") {
            entry.id = "my-" + Entry.makeID(for: entry.term)
        }
        if let existing = customEntry(id: entry.id, in: context) {
            existing.update(with: entry)
        } else {
            context.insert(CustomEntry(entry: entry))
        }
        try? context.save()
        introduce(id: entry.id, in: context, now: now)
        reloadWidgets()
        return entry
    }

    static func deleteCustom(id: String, in context: ModelContext) {
        let customs = (try? context.fetch(FetchDescriptor<CustomEntry>(predicate: #Predicate { $0.entryID == id }))) ?? []
        let states = (try? context.fetch(FetchDescriptor<ReviewState>(predicate: #Predicate { $0.entryID == id }))) ?? []
        customs.forEach(context.delete)
        states.forEach(context.delete)
        try? context.save()
        reloadWidgets()
    }

    // MARK: - Widget snapshot

    struct Snapshot {
        var today: Entry?
        var quiz: Entry?
        var quizRevealed = false
        var dueCount = 0
        var nextDue: Date?
    }

    static func snapshot(now: Date = .now) -> Snapshot {
        let context = ModelContext(DataStore.container)
        let today = todaysEntry(in: context, now: now)
        let due = dueEntries(in: context, now: now, excluding: today?.id)
        let quiz = due.first
        return Snapshot(
            today: today,
            quiz: quiz,
            quizRevealed: quiz.map { isRevealed($0.id) } ?? false,
            dueCount: due.count,
            nextDue: due.isEmpty ? nextDueDate(in: context, now: now) : nil
        )
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
