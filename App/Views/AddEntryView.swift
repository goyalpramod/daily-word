import SwiftUI
import SwiftData

/// Look up a word or phrase, adjust what came back, and add it to your words.
/// Also used to edit one of your own entries.
struct AddEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var query: String
    @State private var draft: Draft?
    @State private var isLoading = false
    @State private var message: String?
    @FocusState private var searchFocused: Bool
    private let autoLookup: Bool
    private let isEditing: Bool

    init(initialTerm: String = "", autoLookup: Bool = false) {
        _query = State(initialValue: initialTerm)
        self.autoLookup = autoLookup && !initialTerm.isEmpty
        self.isEditing = false
    }

    init(editing entry: Entry) {
        _query = State(initialValue: entry.term)
        _draft = State(initialValue: Draft(entry))
        self.autoLookup = false
        self.isEditing = true
    }

    private var curatedMatch: Entry? {
        isEditing ? nil : WordLibrary.shared.entry(matchingTerm: query)
    }

    var body: some View {
        Form {
            if !isEditing {
                SwiftUI.Section {
                    TextField("Look up a word or phrase", text: $query)
                        .font(.system(.title2, design: .serif))
                        .focused($searchFocused)
                        .onSubmit { Task { await lookUp() } }
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .padding(.vertical, 6)
                } footer: {
                    if isLoading {
                        Text("Looking up…")
                    } else if let message {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(message)
                            if draft == nil { Button("Write it in myself") { draft = Draft(term: query) } }
                        }
                    }
                }

                if let curated = curatedMatch {
                    SwiftUI.Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(curated.term).font(.system(.title3, design: .serif))
                            Text(curated.definition).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Button("Add to my reviews") {
                            Vocab.introduce(id: curated.id, in: context)
                            Vocab.reloadWidgets()
                            dismiss()
                        }
                    } header: {
                        Text("Already in the library")
                    }
                }
            }

            if draft != nil { editor }
        }
        .formStyle(.grouped)
        .navigationTitle(isEditing ? "Edit word" : "Add a word")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if draft != nil {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(!(draft?.isValid ?? false))
                } else if !isEditing {
                    Button("Look up") { Task { await lookUp() } }
                        .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
        }
        .task {
            if autoLookup && draft == nil { await lookUp() }
            else if !isEditing { searchFocused = true }
        }
    }

    @ViewBuilder
    private var editor: some View {
        let binding = Binding { draft ?? Draft(term: query) } set: { draft = $0 }
        SwiftUI.Section("Meaning") {
            TextField("Word or phrase", text: binding.term)
            TextField("Definition", text: binding.definition, axis: .vertical).lineLimit(2...6)
            TextField("Example sentence", text: binding.example, axis: .vertical).lineLimit(1...4)
            TextField("Part of speech", text: binding.partOfSpeech)
            TextField("Pronunciation", text: binding.pronunciation)
        }
        SwiftUI.Section("Origin") {
            TextField("Where the word comes from", text: binding.etymology, axis: .vertical).lineLimit(2...10)
            TextField("Root, like melior", text: binding.rootForm)
            TextField("What the root means, like better", text: binding.rootMeaning)
        }
        SwiftUI.Section {
            TextField("Words with the same root", text: binding.related, axis: .vertical)
            TextField("Similar words", text: binding.synonyms, axis: .vertical)
            TextField("Usage note", text: binding.note, axis: .vertical).lineLimit(1...4)
        } header: {
            Text("More")
        } footer: {
            Text("Separate words with commas. Sources: dictionaryapi.dev and Wiktionary.")
        }
    }

    private func lookUp() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, curatedMatch == nil else { return }
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            draft = Draft(try await LookupService().lookUp(term))
        } catch {
            draft = nil
            message = error.localizedDescription
        }
    }

    private func save() {
        guard let draft, draft.isValid else { return }
        Vocab.saveCustom(draft.entry, in: context)
        dismiss()
    }
}

/// Editable, all-strings version of an Entry for the form.
private struct Draft {
    var id = ""
    var term = ""
    var partOfSpeech = ""
    var pronunciation = ""
    var definition = ""
    var example = ""
    var note = ""
    var etymology = ""
    var rootForm = ""
    var rootMeaning = ""
    var related = ""
    var synonyms = ""

    init(term: String) { self.term = term }

    init(_ e: Entry) {
        id = e.id
        term = e.term
        partOfSpeech = e.partOfSpeech ?? ""
        pronunciation = e.pronunciation ?? ""
        definition = e.definition
        example = e.example ?? ""
        note = e.note ?? ""
        etymology = e.etymology ?? ""
        rootForm = e.root?.form ?? ""
        rootMeaning = e.root?.meaning ?? ""
        related = (e.relatedWords ?? []).map(\.term).joined(separator: ", ")
        synonyms = (e.synonyms ?? []).joined(separator: ", ")
    }

    var isValid: Bool { !term.trimmed.isEmpty && !definition.trimmed.isEmpty }

    var entry: Entry {
        let relatedList = related.commaList
        let synonymList = synonyms.commaList
        return Entry(
            id: id,
            term: term.trimmed,
            kind: term.trimmed.contains(" ") ? .phrase : .word,
            partOfSpeech: partOfSpeech.nilIfEmpty,
            pronunciation: pronunciation.nilIfEmpty,
            definition: definition.trimmed,
            example: example.nilIfEmpty,
            etymology: etymology.nilIfEmpty,
            root: rootForm.nilIfEmpty.map { WordRoot(form: $0, language: nil, meaning: rootMeaning.nilIfEmpty) },
            relatedWords: relatedList.isEmpty ? nil : relatedList.map { RelatedWord(term: $0, meaning: nil) },
            synonyms: synonymList.isEmpty ? nil : synonymList,
            note: note.nilIfEmpty,
            category: Entry.customCategory
        )
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { trimmed.isEmpty ? nil : trimmed }
    var commaList: [String] { split(separator: ",").map { String($0).trimmed }.filter { !$0.isEmpty } }
}
