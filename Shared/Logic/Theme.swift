import SwiftUI

/// Design tokens. The app is set like a dictionary page:
/// New York (serif) for words and examples, SF for everything you operate,
/// one ink-blue accent reserved for things you can tap.
enum Theme {
    // Type
    static func headword(_ size: CGFloat = 56) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
    static let wordTitle = Font.system(.title2, design: .serif)
    static let listWord = Font.system(.body, design: .serif)
    static let definition = Font.system(size: 19, weight: .regular, design: .serif)
    static let example = Font.system(size: 17, weight: .regular, design: .serif).italic()
    static let body = Font.system(.body, design: .serif)
    static let sectionTitle = Font.subheadline.weight(.semibold)
    static let meta = Font.subheadline

    // Spacing
    static let pageWidth: CGFloat = 600
    static let pagePadding: CGFloat = 28
    static let sectionGap: CGFloat = 40
}

extension View {
    /// Narrow, readable column used by every page.
    func pageColumn() -> some View {
        self
            .padding(.horizontal, Theme.pagePadding)
            .frame(maxWidth: Theme.pageWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
    }
}
