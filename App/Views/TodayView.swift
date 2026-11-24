import SwiftUI
import SwiftData

/// Today's word as a full page, with a quiet way into reviews at the bottom.
struct TodayView: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var states: [ReviewState]

    @State private var today: Entry?
    @State private var bonus: BonusWord?
    @State private var lookup: LookupTerm?

    private var dueCount: Int {
        let now = Date.now
        return Set(states.filter { $0.dueDate <= now && $0.entryID != today?.id }.map(\.entryID)).count
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.todayPath) {
            ScrollView {
                if let today {
                    EntryPage(
                        entry: today,
                        caption: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                        onLookUp: { lookup = LookupTerm(term: $0) }
                    ) {
                        footer
                    }
                    .pageColumn()
                    .padding(.vertical, 32)
                }
            }
            .scrollIndicators(.hidden)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(for: EntryRoute.self) { EntryDetailView(entryID: $0.id) }
            .modifier(LookupSheet(term: $lookup))
        }
        .task { await load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await load() } }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().padding(.bottom, 10)
            if dueCount > 0 {
                Button { router.tab = .review } label: {
                    Text("Review \(dueCount) past word\(dueCount == 1 ? "" : "s")")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            } else {
                Text("No reviews due. Past words return here when it's time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let bonus {
                Button {
                    if let curated = WordLibrary.shared.entry(matchingTerm: bonus.term) {
                        router.todayPath.append(EntryRoute(id: curated.id))
                    } else {
                        lookup = LookupTerm(term: bonus.term)
                    }
                } label: {
                    (Text("Also today on Wiktionary: ").foregroundStyle(.secondary)
                     + Text(bonus.term).font(.system(.subheadline, design: .serif).italic()).foregroundStyle(Color.accentColor))
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    private func load() async {
        today = Vocab.todaysEntry(in: context)
        Vocab.reloadWidgets()
        bonus = await BonusWordService().todaysWord()
    }
}
