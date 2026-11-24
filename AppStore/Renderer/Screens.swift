import SwiftUI

// Each screen takes the device's logical size so the same view works for
// iPhone, iPad and the Mac window. Content uses the app's real EntryPage.

struct TodayContent: View {
    let entry: Entry
    var dark = false
    var scroll: CGFloat = 0
    var topInset: CGFloat = 76
    var appear = 1.0

    var body: some View {
        EntryPage(entry: entry, caption: "Tuesday, November 24") {
            VStack(alignment: .leading, spacing: 14) {
                Divider().padding(.bottom, 10)
                Text("Review 3 past words").font(.body.weight(.medium)).foregroundStyle(.tint)
                (Text("Also today on Wiktionary: ").foregroundStyle(.secondary)
                 + Text("interplay").font(.system(.subheadline, design: .serif).italic()).foregroundStyle(Ink.color(dark)))
                    .font(.subheadline)
            }
            .padding(.top, 8)
        }
        .pageColumn()
        .fixedSize(horizontal: false, vertical: true)   // keep natural height; we scroll by offset
        .padding(.top, topInset)
        .offset(y: -scroll + 12 * (1 - appear))
        .opacity(appear)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct ReviewContent: View {
    let entry: Entry
    var dark = false
    var progress = 0.33
    var revealed = 1.0
    var pressed = 0.0
    var bottomInset: CGFloat = 110
    var topInset: CGFloat = 64

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule().fill(Ink.color(dark)).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
            .padding(.top, topInset)

            Spacer()
            VStack(alignment: .leading, spacing: 18) {
                Text(entry.term)
                    .font(Theme.headword(entry.term.count > 14 ? 38 : 50))
                    .tracking(-0.5)
                ZStack(alignment: .topLeading) {
                    Text("Do you remember what it means? Tap to check.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .opacity(1 - revealed)
                    VStack(alignment: .leading, spacing: 18) {
                        Text(entry.definition).font(Theme.definition).lineSpacing(5)
                        if let example = entry.example {
                            Text("“\(example)”").font(Theme.example).foregroundStyle(.secondary)
                        }
                    }
                    .opacity(revealed)
                    .offset(y: 6 * (1 - revealed))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()

            HStack(spacing: 12) {
                PillButton(title: "Missed", prominent: false, dark: dark)
                PillButton(title: "Got it", prominent: true, dark: dark, pressed: pressed)
            }
            .opacity(revealed)
            .padding(.bottom, bottomInset)
        }
        .pageColumn()
    }
}

struct WidgetsContent: View {
    let today: Entry
    let quiz: Entry
    var answer = 1.0
    var pressed = 0.0
    var topInset: CGFloat = 86

    var body: some View {
        VStack(spacing: 24) {
            WordWidgetMedium(entry: today)
            HStack(spacing: 24) {
                ZStack {
                    ReviewWidgetQuestion(entry: quiz).opacity(1 - answer)
                    ReviewWidgetAnswer(entry: quiz, pressed: pressed).opacity(answer)
                }
                WordWidgetSmall(entry: WordLibrary.store.byID["sanguine"]!)
            }
        }
        .padding(.top, topInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// Mirrors AddEntryView after a lookup (a grouped form). Content is a real lookup result.
struct AddContent: View {
    var dark = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Cancel").foregroundStyle(.tint)
                Spacer()
                Text("Add a word").font(.headline)
                Spacer()
                Text("Add").fontWeight(.semibold).foregroundStyle(.tint)
            }
            .padding(.horizontal, 20)
            .padding(.top, 70)
            .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 22) {
                group { Text("petrichor").font(.system(.title2, design: .serif)) }
                section("Meaning") {
                    row("petrichor")
                    row("A pleasant, earthy smell that comes with the first rain after a dry spell.")
                    row("I love that petrichor when the first storm of summer rolls in.", secondary: true)
                    row("noun")
                }
                section("Origin") {
                    row("Coined in 1964 by Australian scientists Isabel Joy Bear and Richard Thomas, from Greek petra (stone) + ichor, the fluid said to flow in the veins of the gods.")
                    row("petra")
                    row("stone")
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(dark ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97))
    }

    private func group<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { c() }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(dark ? Color(white: 0.11) : .white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).foregroundStyle(.secondary).padding(.leading, 16)
            VStack(alignment: .leading, spacing: 0) { c() }
                .background(dark ? Color(white: 0.11) : .white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func row(_ text: String, secondary: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(.body)
                .foregroundStyle(secondary ? .secondary : .primary)
                .padding(.horizontal, 16).padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider().padding(.leading, 16)
        }
    }
}

// MARK: - App Store frame: a plain-language caption above the screen

struct StoreFrame<Screen: View>: View {
    let canvas: CGSize
    let title: String
    let subtitle: String
    var dark = false
    let screenSize: CGSize
    let screenScale: CGFloat
    let screenTop: CGFloat
    var cornerRadius: CGFloat = 56
    var titleSize: CGFloat = 38
    var margin: CGFloat = 36
    var topPadding: CGFloat = 76
    @ViewBuilder var screen: Screen

    var body: some View {
        ZStack(alignment: .topLeading) {
            (dark ? Color.black : Color.white)

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: titleSize, weight: .regular, design: .serif))
                    .tracking(-0.6)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: titleSize * 0.45))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: canvas.width - margin * 2, alignment: .leading)
            .padding(.leading, margin)
            .padding(.top, topPadding)

            screen
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(dark ? Color.white.opacity(0.14) : Color.black.opacity(0.09), lineWidth: 1.5))
                .shadow(color: .black.opacity(dark ? 0 : 0.10), radius: 40, y: 18)
                .scaleEffect(screenScale, anchor: .topLeading)
                .frame(width: screenSize.width * screenScale, height: screenSize.height * screenScale, alignment: .topLeading)
                .offset(x: (canvas.width - screenSize.width * screenScale) / 2, y: screenTop)
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .clipped()
        .environment(\.colorScheme, dark ? .dark : .light)
    }
}

struct EndCard: View {
    var dark = false
    let icon: NSImage

    var body: some View {
        VStack(spacing: 22) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
            Text("Daily Word")
                .font(.system(size: 40, design: .serif))
                .tracking(-0.5)
            Text("A new word every day, and where it came from.")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(dark ? Color.black : Color.white)
        .environment(\.colorScheme, dark ? .dark : .light)
    }
}
