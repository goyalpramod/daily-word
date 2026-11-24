import SwiftUI
import SwiftData

struct LibraryView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case learning = "Learning", mine = "Mine", all = "All"
        var id: String { rawValue }
    }

    @Query private var states: [ReviewState]
    @Query(sort: \CustomEntry.createdAt, order: .reverse) private var customs: [CustomEntry]
    @State private var filter: Filter = .learning
    @State private var search = ""
    @State private var adding = false

    private var stateByID: [String: ReviewState] {
        Dictionary(states.map { ($0.entryID, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private var customEntries: [Entry] { customs.compactMap(\.entry) }

    private var entries: [Entry] {
        let base: [Entry]
        switch filter {
        case .learning:
            let byID = stateByID
            base = (WordLibrary.shared.entries + customEntries)
                .filter { byID[$0.id] != nil }
                .sorted { (byID[$0.id]?.introducedOn ?? .distantPast) > (byID[$1.id]?.introducedOn ?? .distantPast) }
        case .mine:
            base = customEntries
        case .all:
            base = customEntries + WordLibrary.shared.entries
        }
        guard !search.isEmpty else { return base }
        return base.filter {
            $0.term.localizedCaseInsensitiveContains(search) || $0.definition.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowSeparator(.hidden)
                .padding(.bottom, 8)

                ForEach(entries) { entry in
                    NavigationLink(value: EntryRoute(id: entry.id)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.term).font(.system(.title3, design: .serif))
                            Text(entry.definition)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .overlay { if entries.isEmpty { empty } }
            .searchable(text: $search, prompt: "Search")
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                        .help("Add a word")
                        .accessibilityLabel("Add a word")
                }
            }
            .navigationDestination(for: EntryRoute.self) { EntryDetailView(entryID: $0.id) }
            .sheet(isPresented: $adding) {
                NavigationStack { AddEntryView() }
                    #if os(macOS)
                    .frame(minWidth: 480, minHeight: 600)
                    #endif
            }
        }
    }

    @ViewBuilder
    private var empty: some View {
        if !search.isEmpty {
            ContentUnavailableView.search(text: search)
        } else {
            VStack(spacing: 10) {
                Text(filter == .mine ? "Words you add appear here." : "Words you've met appear here.")
                    .foregroundStyle(.secondary)
                if filter == .mine {
                    Button("Add a word") { adding = true }
                }
            }
            .font(.subheadline)
        }
    }
}
