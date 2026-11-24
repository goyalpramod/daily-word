import SwiftUI
import SwiftData

/// Any word's full page, plus your progress with it.
struct EntryDetailView: View {
    let entryID: String

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var states: [ReviewState]
    @Query private var customs: [CustomEntry]
    @State private var lookup: LookupTerm?
    @State private var editing: Entry?

    init(entryID: String) {
        self.entryID = entryID
        _states = Query(filter: #Predicate<ReviewState> { $0.entryID == entryID })
        _customs = Query(filter: #Predicate<CustomEntry> { $0.entryID == entryID })
    }

    private var entry: Entry? {
        WordLibrary.shared.byID[entryID] ?? customs.first?.entry
    }

    var body: some View {
        Group {
            if let entry {
                ScrollView {
                    EntryPage(entry: entry, onLookUp: { lookup = LookupTerm(term: $0) }) {
                        if let state = states.first { ProgressLine(state: state) }
                    }
                    .pageColumn()
                    .padding(.vertical, 24)
                }
                .scrollIndicators(.hidden)
            } else {
                ContentUnavailableView("This word was deleted", systemImage: "text.page.slash")
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if let entry, entry.isCustom {
                ToolbarItem {
                    Menu {
                        Button("Edit", systemImage: "pencil") { editing = entry }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            Vocab.deleteCustom(id: entry.id, in: context)
                            dismiss()
                        }
                    } label: { Image(systemName: "ellipsis") }
                }
            }
        }
        .modifier(LookupSheet(term: $lookup))
        .sheet(item: $editing) { entry in
            NavigationStack { AddEntryView(editing: entry) }
                #if os(macOS)
                .frame(minWidth: 480, minHeight: 600)
                #endif
        }
    }
}

/// One quiet line about how well you know a word.
struct ProgressLine: View {
    let state: ReviewState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().padding(.bottom, 10)
            Text(summary).font(.subheadline)
            Text("Learned \(state.introducedOn.formatted(date: .long, time: .omitted)). Next review \(state.dueDate.formatted(.relative(presentation: .named))).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var summary: String {
        let reviews = state.timesCorrect + state.timesWrong
        guard reviews > 0 else { return "New" }
        let level = switch state.strength {
        case ..<0.4: "Learning"
        case ..<0.8: "Getting there"
        default: "Known well"
        }
        return "\(level). Right \(state.timesCorrect) of \(reviews) times."
    }
}
