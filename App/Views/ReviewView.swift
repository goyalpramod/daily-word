import SwiftUI
import SwiftData

/// One word on an empty page. Tap to see the meaning, then say whether you knew it.
struct ReviewView: View {
    @Environment(\.modelContext) private var context
    @State private var queue: [Entry] = []
    @State private var total = 0
    @State private var revealed = false
    @State private var reviewedCount = 0
    @State private var correctCount = 0

    var body: some View {
        NavigationStack {
            Group {
                if let current = queue.first {
                    session(current)
                } else {
                    finished
                }
            }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(for: EntryRoute.self) { EntryDetailView(entryID: $0.id) }
        }
        .onAppear(perform: reload)
    }

    private func session(_ entry: Entry) -> some View {
        VStack(spacing: 0) {
            // Progress through this session: a real sequence, so a bar is honest.
            ProgressView(value: Double(total - queue.count), total: Double(max(total, 1)))
                .progressViewStyle(.linear)
                .tint(Color.accentColor)
                .padding(.top, 12)

            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                Text(entry.term)
                    .font(Theme.headword(entry.term.count > 14 ? 38 : 50))
                    .tracking(-0.5)
                    .fixedSize(horizontal: false, vertical: true)
                if revealed {
                    Text(entry.definition)
                        .font(Theme.definition)
                        .lineSpacing(5)
                        .transition(.opacity.combined(with: .offset(y: 6)))
                    if let example = entry.example {
                        Text("“\(example)”")
                            .font(Theme.example)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                } else {
                    Text("Do you remember what it means? Tap to check.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeOut(duration: 0.25)) { revealed = true } }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(revealed ? "" : "Shows the meaning")

            Spacer()

            HStack(spacing: 12) {
                Button { grade(entry, .missed) } label: {
                    Text("Missed").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("1", modifiers: [])
                Button { grade(entry, .correct) } label: {
                    Text("Got it").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("2", modifiers: [])
            }
            .controlSize(.large)
            .opacity(revealed ? 1 : 0)
            .disabled(!revealed)
            .padding(.bottom, 24)
        }
        .pageColumn()
    }

    private var finished: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(reviewedCount > 0 ? "Done for today." : "Nothing to review.")
                .font(Theme.headword(36))
            Text(reviewedCount > 0
                 ? "You knew \(correctCount) of \(reviewedCount). Missed words come back tomorrow."
                 : "Words return here on a schedule. The better you know one, the longer it stays away.")
                .font(Theme.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .pageColumn()
        .frame(maxHeight: .infinity)
    }

    private func grade(_ entry: Entry, _ grade: Scheduler.Grade) {
        Vocab.grade(id: entry.id, grade, in: context)
        reviewedCount += 1
        if grade == .correct { correctCount += 1 }
        withAnimation(.easeInOut(duration: 0.2)) {
            revealed = false
            queue.removeFirst()
        }
    }

    private func reload() {
        guard queue.isEmpty else { return }
        let today = Vocab.todaysEntry(in: context)
        queue = Vocab.dueEntries(in: context, excluding: today?.id)
        total = queue.count
        reviewedCount = 0
        correctCount = 0
        revealed = false
    }
}
