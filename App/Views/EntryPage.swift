import SwiftUI
import AVFoundation

/// A word set like a dictionary page. Used by Today and by the detail screen.
struct EntryPage<Footer: View>: View {
    let entry: Entry
    var caption: String?
    var onLookUp: (String) -> Void = { _ in }
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sectionGap) {
            headword
            meaning
            if let note = entry.note, !note.isEmpty {
                block("Usage") { Text(note).font(Theme.body).lineSpacing(4) }
            }
            if let etymology = entry.etymology, !etymology.isEmpty {
                block("Origin") {
                    Text(etymology).font(Theme.body).lineSpacing(5)
                    if let root = entry.root { rootLine(root) }
                }
            }
            if let related = entry.relatedWords, !related.isEmpty {
                block(entry.root == nil ? "Related" : "Same root") {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(related) { relatedRow($0) }
                    }
                }
            }
            if let synonyms = entry.synonyms, !synonyms.isEmpty {
                block("Similar") {
                    Text(synonyms.joined(separator: ", ")).font(Theme.body).foregroundStyle(.secondary)
                }
            }
            footer
        }
        .textSelection(.enabled)
    }

    private var headword: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let caption {
                Text(caption).font(Theme.meta).foregroundStyle(.secondary)
            }
            Text(entry.term)
                .font(Theme.headword(entry.term.count > 14 ? 40 : 56))
                .tracking(-0.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, caption == nil ? 0 : 8)
            HStack(spacing: 14) {
                if let pron = entry.pronunciation { Text(pron) }
                if let pos = entry.partOfSpeech { Text(pos).italic() }
                SpeakButton(text: entry.term)
            }
            .font(Theme.meta)
            .foregroundStyle(.secondary)
        }
    }

    private var meaning: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry.definition)
                .font(Theme.definition)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            if let example = entry.example {
                Text("“\(example)”")
                    .font(Theme.example)
                    .lineSpacing(4)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func rootLine(_ root: WordRoot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(root.form).font(.system(.title3, design: .serif).italic())
            Text([root.language, root.meaning.map { "“\($0)”" }].compactMap { $0 }.joined(separator: ", "))
                .font(Theme.meta)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func relatedRow(_ word: RelatedWord) -> some View {
        let known = WordLibrary.shared.entry(matchingTerm: word.term)
        let label = VStack(alignment: .leading, spacing: 2) {
            Text(word.term).font(Theme.listWord).foregroundStyle(.tint)
            if let meaning = word.meaning {
                Text(meaning).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())

        if let known {
            NavigationLink(value: EntryRoute(id: known.id)) { label }.buttonStyle(.plain)
        } else {
            Button { onLookUp(word.term) } label: { label }.buttonStyle(.plain)
        }
    }

    private func block<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(Theme.sectionTitle).foregroundStyle(.secondary)
            content()
        }
    }
}

extension EntryPage where Footer == EmptyView {
    init(entry: Entry, caption: String? = nil, onLookUp: @escaping (String) -> Void = { _ in }) {
        self.init(entry: entry, caption: caption, onLookUp: onLookUp) { EmptyView() }
    }
}

struct SpeakButton: View {
    let text: String

    var body: some View {
        Button { Speaker.shared.speak(text) } label: {
            Image(systemName: "speaker.wave.2")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .help("Pronounce")
        .accessibilityLabel("Pronounce \(text)")
    }
}

final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synth.speak(utterance)
    }
}

/// Presents the lookup flow for a word that isn't in the library yet.
struct LookupSheet: ViewModifier {
    @Binding var term: LookupTerm?

    func body(content: Content) -> some View {
        content.sheet(item: $term) { item in
            NavigationStack { AddEntryView(initialTerm: item.term, autoLookup: true) }
                #if os(macOS)
                .frame(minWidth: 480, minHeight: 600)
                #endif
        }
    }
}

struct LookupTerm: Identifiable {
    let term: String
    var id: String { term }
}
