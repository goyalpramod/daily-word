import SwiftUI
import os

// MARK: - Stubs for app types the shared views reference

enum SharedConfig { static let logger = Logger() }
struct EntryRoute: Hashable { let id: String }
struct AddEntryView: View {
    init(initialTerm: String, autoLookup: Bool) {}
    var body: some View { EmptyView() }
}

// MARK: - Palette (mirrors the app's asset catalog)

enum Ink {
    static let light = Color(red: 0.149, green: 0.204, blue: 0.549)
    static let dark = Color(red: 0.604, green: 0.647, blue: 0.949)
    static func color(_ dark: Bool) -> Color { dark ? Ink.dark : Ink.light }
}

func ease(_ x: Double) -> Double {
    let t = min(max(x, 0), 1)
    return t * t * (3 - 2 * t)
}

/// 0→1 over [start, end], eased.
func phase(_ t: Double, _ start: Double, _ end: Double) -> Double {
    ease((t - start) / (end - start))
}

// MARK: - iPhone / iPad chrome

struct StatusBar: View {
    var island = true

    var body: some View {
        ZStack {
            HStack {
                Text("9:41").font(.system(size: 17, weight: .semibold))
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "cellularbars")
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100")
                }
                .font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 34)
            if island {
                Capsule().fill(.black).frame(width: 124, height: 36)
            }
        }
        .frame(height: 54)
        .padding(.top, 4)
    }
}

struct TabBarMock: View {
    let selected: Int
    let dark: Bool

    var body: some View {
        HStack(spacing: 0) {
            item("text.book.closed", "Today", 0)
            item("rectangle.stack", "Review", 1)
            item("books.vertical", "Library", 2)
        }
        .padding(4)
        .background(Capsule().fill(dark ? Color(white: 0.13) : Color(white: 0.965)))
        .overlay(Capsule().strokeBorder(dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
        .shadow(color: .black.opacity(dark ? 0 : 0.06), radius: 12, y: 4)
    }

    private func item(_ icon: String, _ label: String, _ index: Int) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 19))
            Text(label).font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(index == selected ? Ink.color(dark) : Color.primary)
        .frame(width: 88, height: 54)
        .background(Capsule().fill(index == selected ? (dark ? Color(white: 0.22) : Color(white: 0.9)) : .clear))
    }
}

/// A phone/tablet screen: background, status bar, optional tab bar.
struct DeviceScreen<Content: View>: View {
    let size: CGSize
    var dark = false
    var tab: Int? = 0
    var island = true
    var background: AnyView? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            if let background { background } else { (dark ? Color.black : Color.white) }
            content.frame(width: size.width, height: size.height, alignment: .top).clipped()
            StatusBar(island: island)
                .background(background == nil ? (dark ? Color.black : Color.white) : Color.clear)
            if let tab {
                VStack { Spacer(); TabBarMock(selected: tab, dark: dark).padding(.bottom, 22) }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .environment(\.colorScheme, dark ? .dark : .light)
        .tint(Ink.color(dark))
    }
}

// MARK: - Mac window chrome

struct MacWindow<Content: View>: View {
    let size: CGSize
    var dark = false
    var tab = 0
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 8) {
                    Circle().fill(Color(red: 1, green: 0.37, blue: 0.34))
                    Circle().fill(Color(red: 1, green: 0.74, blue: 0.18))
                    Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.25))
                    Spacer()
                }
                .frame(height: 13)
                .padding(.leading, 20)
                HStack(spacing: 2) {
                    ForEach(Array(["Today", "Review", "Library"].enumerated()), id: \.offset) { i, label in
                        Text(label)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Capsule().fill(i == tab ? (dark ? Color(white: 0.3) : Color(white: 0.86)) : .clear))
                    }
                }
                .padding(3)
                .background(Capsule().fill(dark ? Color(white: 0.2) : Color(white: 0.95)))
            }
            .frame(height: 52)
            content.frame(width: size.width, height: size.height - 52, alignment: .top).clipped()
        }
        .frame(width: size.width, height: size.height)
        .background(dark ? Color(white: 0.13) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1)))
        .environment(\.colorScheme, dark ? .dark : .light)
        .tint(Ink.color(dark))
    }
}

// MARK: - Widgets (mirror Widget/DailyWordWidgets.swift)

let wallpaper = LinearGradient(
    colors: [Color(red: 0.78, green: 0.81, blue: 0.93), Color(red: 0.93, green: 0.94, blue: 0.98)],
    startPoint: .top, endPoint: .bottom)

struct WidgetCard<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    var dark = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(dark ? Color(white: 0.11) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
            .environment(\.colorScheme, dark ? .dark : .light)
            .tint(Ink.color(dark))
    }
}

struct WidgetHeadword: View {
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

struct WordWidgetMedium: View {
    let entry: Entry
    var body: some View {
        WidgetCard(width: 364, height: 170) {
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeadword(term: entry.term, size: 30)
                HStack(spacing: 10) {
                    if let p = entry.pronunciation { Text(p) }
                    if let pos = entry.partOfSpeech { Text(pos).italic() }
                }
                .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(entry.definition).font(.system(.subheadline, design: .serif)).lineLimit(2)
            }
        }
    }
}

struct WordWidgetSmall: View {
    let entry: Entry
    var body: some View {
        WidgetCard(width: 170, height: 170) {
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeadword(term: entry.term, size: 26)
                Text(entry.definition)
                    .font(.system(.footnote, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
    }
}

struct ReviewWidgetQuestion: View {
    let entry: Entry
    var remaining = 3
    var body: some View {
        WidgetCard(width: 170, height: 170) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(remaining) to review").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                WidgetHeadword(term: entry.term, size: 24)
                Text("Tap to see the meaning").font(.caption).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

struct ReviewWidgetAnswer: View {
    let entry: Entry
    var pressed = 0.0
    var body: some View {
        WidgetCard(width: 170, height: 170) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.term).font(.system(.headline, design: .serif)).lineLimit(1)
                Text(entry.definition)
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Spacer(minLength: 4)
                HStack(spacing: 6) {
                    PillButton(title: "Missed", prominent: false, dark: false, compact: true)
                    PillButton(title: "Got it", prominent: true, dark: false, compact: true, pressed: pressed)
                }
            }
        }
    }
}

struct PillButton: View {
    let title: String
    let prominent: Bool
    let dark: Bool
    var compact = false
    var pressed = 0.0

    var body: some View {
        Text(title)
            .font(compact ? .caption.weight(.medium) : .body.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 7 : 14)
            .foregroundStyle(prominent ? (dark ? Color.black : .white) : Ink.color(dark))
            .background(Capsule().fill(prominent ? Ink.color(dark) : (dark ? Color(white: 0.18) : Color(white: 0.93))))
            .scaleEffect(1 - 0.05 * pressed)
            .opacity(1 - 0.25 * pressed)
    }
}
