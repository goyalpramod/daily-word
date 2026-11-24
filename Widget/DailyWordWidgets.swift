import SwiftUI
import WidgetKit
import AppIntents

@main
struct DailyWordWidgetBundle: WidgetBundle {
    var body: some Widget {
        WordOfTheDayWidget()
        ReviewWidget()
    }
}

// MARK: - Timeline

struct DailyEntry: TimelineEntry {
    let date: Date
    let snapshot: Vocab.Snapshot
}

struct DailyProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyEntry {
        DailyEntry(date: .now, snapshot: .init(today: .sample, quiz: .sample))
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : DailyEntry(date: .now, snapshot: Vocab.snapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
        let now = Date.now
        let entry = DailyEntry(date: now, snapshot: Vocab.snapshot(now: now))
        // Refresh just after midnight for the new word and newly due reviews.
        let tomorrow = Scheduler.dueDate(afterDays: 1, from: now).addingTimeInterval(60)
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

// MARK: - Word of the Day

struct WordOfTheDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WordOfTheDay", provider: DailyProvider()) { entry in
            WordOfTheDayView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Word of the Day")
        .description("A new word or phrase every day.")
        .supportedFamilies(families)
    }

    private var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline]
        #else
        [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }
}

struct WordOfTheDayView: View {
    let entry: DailyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let word = entry.snapshot.today {
            content(word).widgetURL(DeepLink.url(for: word.id))
        } else {
            Text("Open Daily Word to get started.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func content(_ word: Entry) -> some View {
        switch family {
        #if os(iOS)
        case .accessoryInline:
            Text(word.term)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(word.term).font(.system(.headline, design: .serif)).widgetAccentable()
                Text(word.definition).font(.caption).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        #endif
        case .systemSmall:
            VStack(alignment: .leading, spacing: 6) {
                Headword(term: word.term, size: 26)
                Text(word.definition)
                    .font(.system(.footnote, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemLarge:
            VStack(alignment: .leading, spacing: 10) {
                Headword(term: word.term, size: 40)
                Meta(word: word)
                Text(word.definition)
                    .font(.system(.body, design: .serif))
                    .lineLimit(3)
                    .padding(.top, 4)
                if let example = word.example {
                    Text("“\(example)”")
                        .font(.system(.subheadline, design: .serif).italic())
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer(minLength: 8)
                if let etymology = word.etymology {
                    Text("Origin").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(etymology)
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default: // medium
            VStack(alignment: .leading, spacing: 6) {
                Headword(term: word.term, size: 30)
                Meta(word: word)
                Spacer(minLength: 0)
                Text(word.definition)
                    .font(.system(.subheadline, design: .serif))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Review

struct ReviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Review", provider: DailyProvider()) { entry in
            ReviewWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Review")
        .description("Test yourself on a past word. Words you miss come back sooner.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ReviewWidgetView: View {
    let entry: DailyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let snap = entry.snapshot
        if let quiz = snap.quiz {
            if snap.quizRevealed {
                answer(quiz, remaining: snap.dueCount)
            } else {
                question(quiz, remaining: snap.dueCount)
            }
        } else {
            caughtUp(next: snap.nextDue)
        }
    }

    /// The whole card is the reveal button.
    private func question(_ quiz: Entry, remaining: Int) -> some View {
        Button(intent: RevealAnswerIntent(entryID: quiz.id)) {
            VStack(alignment: .leading, spacing: 6) {
                Text(remaining > 1 ? "\(remaining) to review" : "Review")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Headword(term: quiz.term, size: family == .systemSmall ? 24 : 30)
                Text("Tap to see the meaning")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func answer(_ quiz: Entry, remaining: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(quiz.term)
                .font(.system(family == .systemSmall ? .headline : .title3, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(quiz.definition)
                .font(.system(.caption, design: .serif))
                .foregroundStyle(.secondary)
                .lineLimit(family == .systemSmall ? 3 : 3)
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                Button(intent: GradeAnswerIntent(entryID: quiz.id, correct: false)) {
                    Text("Missed").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                Button(intent: GradeAnswerIntent(entryID: quiz.id, correct: true)) {
                    Text("Got it").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(DeepLink.url(for: quiz.id))
    }

    private func caughtUp(next: Date?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
            Text("Nothing to review.")
                .font(.system(.headline, design: .serif))
            if let next {
                Text("Next one \(next, style: .relative) from now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Today's word shows up here tomorrow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(DeepLink.reviewURL)
    }
}

// MARK: - Pieces

private struct Headword: View {
    let term: String
    let size: CGFloat

    var body: some View {
        Text(term)
            .font(.system(size: term.count > 14 ? size * 0.75 : size, weight: .regular, design: .serif))
            .tracking(-0.3)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
    }
}

private struct Meta: View {
    let word: Entry

    var body: some View {
        HStack(spacing: 10) {
            if let pron = word.pronunciation { Text(pron) }
            if let pos = word.partOfSpeech { Text(pos).italic() }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

extension Entry {
    static let sample = Entry(
        id: "ameliorate",
        term: "ameliorate",
        kind: .word,
        partOfSpeech: "verb",
        pronunciation: "uh-MEEL-yuh-rayt",
        definition: "To make something bad or unsatisfactory better.",
        example: "A quick apology did a lot to ameliorate the tension.",
        etymology: "From Latin ad- (towards) + melior (better), via French améliorer.",
        root: WordRoot(form: "melior", language: "Latin", meaning: "better"),
        relatedWords: nil,
        synonyms: ["improve", "ease"],
        note: nil,
        category: "conversation"
    )
}
