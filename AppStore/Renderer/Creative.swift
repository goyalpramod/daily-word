import SwiftUI

// App Store "creative assets" (iOS 27+): the product page header and the search results image.
//
// What the research says works (and what Apple allows):
//  • One clear, benefit-first idea in ≤ 6 words, readable at thumbnail size.
//  • Backed by the real product (here: the actual widgets), not abstract art.
//  • Key content inside Apple's safe area; edges may be cropped per device.
//  • No prices ("free"), URLs, ©, or awards in creative assets.

private let inkTop = Color(red: 0.19, green: 0.26, blue: 0.62)
private let inkBottom = Color(red: 0.10, green: 0.14, blue: 0.40)

private struct InkBackground: View {
    var body: some View {
        LinearGradient(colors: [inkTop, Ink.light, inkBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Scales a fixed-size widget mock while keeping layout size in sync.
private struct Scaled<Content: View>: View {
    let size: CGSize
    let scale: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        content
            .scaleEffect(scale)
            .frame(width: size.width * scale, height: size.height * scale)
    }
}

private struct Headline: View {
    let title: String
    let subtitle: String
    let size: CGFloat
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: size * 0.32) {
            Text(title)
                .font(.system(size: size, weight: .regular, design: .serif))
                .tracking(-size * 0.015)
                .lineSpacing(size * 0.02)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.system(size: size * 0.33, weight: .regular))
                .foregroundStyle(.white.opacity(0.78))
                .lineSpacing(size * 0.08)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: width, alignment: .leading)
    }
}

private struct SafeAreaOutline: View {
    let safe: CGRect
    var body: some View {
        Rectangle().strokeBorder(Color.red, lineWidth: 2)
            .frame(width: safe.width, height: safe.height)
            .position(x: safe.midX, y: safe.midY)
    }
}

/// 21:9 product page header. Safe area holds the promise + the Review card;
/// the Word of the Day widgets either side show up on wider crops.
struct HeaderAsset: View {
    let canvas: CGSize
    let safe: CGRect
    let today: Entry
    let quiz: Entry
    let side: Entry
    var showSafeArea = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            InkBackground()

            Scaled(size: CGSize(width: 364, height: 170), scale: 1.32) { WordWidgetMedium(entry: today) }
                .position(x: safe.minX / 2, y: canvas.height / 2)

            Scaled(size: CGSize(width: 170, height: 170), scale: 1.32) { WordWidgetSmall(entry: side) }
                .position(x: safe.maxX + (canvas.width - safe.maxX) / 2, y: canvas.height / 2)

            HStack(alignment: .center, spacing: 44) {
                Headline(title: "Say exactly\nwhat you mean.",
                         subtitle: "A new word every day, where it came from, and quick reviews on your home screen.",
                         size: 58, width: 470)
                Scaled(size: CGSize(width: 170, height: 170), scale: 1.55) { ReviewWidgetAnswer(entry: quiz) }
            }
            .frame(width: safe.width - 48, height: safe.height)
            .position(x: safe.midX, y: safe.midY)

            if showSafeArea { SafeAreaOutline(safe: safe) }
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
    }
}

/// 3:2 search results image: the promise on the left, the product on the right.
struct SearchAsset: View {
    let canvas: CGSize
    let safe: CGRect
    let today: Entry
    let quiz: Entry
    let side: Entry
    var ghosts: [Entry] = []
    var showSafeArea = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            InkBackground()

            HStack(alignment: .center, spacing: 64) {
                Headline(title: "One word a day,\nand its story.",
                         subtitle: "Learn words for real conversations, see where they came from, and review them from your home screen.",
                         size: 66, width: 500)
                VStack(spacing: 22) {
                    Scaled(size: CGSize(width: 364, height: 170), scale: 1.24) { WordWidgetMedium(entry: today) }
                    HStack(spacing: 22) {
                        Scaled(size: CGSize(width: 170, height: 170), scale: 1.24) { ReviewWidgetAnswer(entry: quiz) }
                        Scaled(size: CGSize(width: 170, height: 170), scale: 1.24) { WordWidgetSmall(entry: side) }
                    }
                }
                // Faint widgets above and below, like a home screen continuing past the crop.
                .overlay(alignment: .top) { ghostRow(ghosts.first).alignmentGuide(.top) { $0[.bottom] + 22 } }
                .overlay(alignment: .bottom) { ghostRow(ghosts.dropFirst().first).alignmentGuide(.bottom) { $0[.top] - 22 } }
            }
            .frame(width: safe.width - 48, height: safe.height)
            .position(x: safe.midX, y: safe.midY)

            if showSafeArea { SafeAreaOutline(safe: safe) }
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
    }
}

private extension SearchAsset {
    @ViewBuilder
    func ghostRow(_ entry: Entry?) -> some View {
        if let entry {
            Scaled(size: CGSize(width: 364, height: 170), scale: 1.24) { WordWidgetMedium(entry: entry) }
                .opacity(0.22)
        }
    }
}
