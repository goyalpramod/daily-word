import AppIntents
import SwiftData
import WidgetKit

// Buttons inside interactive widgets (iOS 17 / macOS 14) run App Intents.
// After `perform()` returns, WidgetKit reloads the widget's timeline, so the
// card flips or moves on to the next due word.

struct RevealAnswerIntent: AppIntent {
    static var title: LocalizedStringResource = "Reveal answer"
    static var isDiscoverable = false

    @Parameter(title: "Entry ID") var entryID: String

    init() {}
    init(entryID: String) { self.entryID = entryID }

    func perform() async throws -> some IntentResult {
        Vocab.setRevealed(entryID)
        return .result()
    }
}

struct GradeAnswerIntent: AppIntent {
    static var title: LocalizedStringResource = "Grade answer"
    static var isDiscoverable = false

    @Parameter(title: "Entry ID") var entryID: String
    @Parameter(title: "Correct") var correct: Bool

    init() {}
    init(entryID: String, correct: Bool) {
        self.entryID = entryID
        self.correct = correct
    }

    func perform() async throws -> some IntentResult {
        let context = ModelContext(DataStore.container)
        Vocab.grade(id: entryID, correct ? .correct : .missed, in: context)
        return .result()
    }
}
