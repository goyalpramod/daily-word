import Foundation

/// A word or phrase, either from the bundled curated lists or added by the user.
/// Matches the JSON schema described in docs/WORD_SCHEMA.md.
struct Entry: Codable, Hashable, Identifiable {
    var id: String
    var term: String
    var kind: Kind
    var partOfSpeech: String?
    var pronunciation: String?
    var definition: String
    var example: String?
    var etymology: String?
    var root: WordRoot?
    var relatedWords: [RelatedWord]?
    var synonyms: [String]?
    var note: String?
    var category: String

    enum Kind: String, Codable, Hashable {
        case word, phrase
    }

    static let customCategory = "my-words"

    var isCustom: Bool { category == Entry.customCategory }

    /// Human-friendly category title, e.g. "speech-phrases" -> "Speech phrases".
    var categoryTitle: String { Entry.title(forCategory: category) }

    static func title(forCategory category: String) -> String {
        switch category {
        case customCategory: return "My words"
        case "speech-phrases": return "Phrases"
        default:
            let spaced = category.replacingOccurrences(of: "-", with: " ")
            return spaced.prefix(1).uppercased() + spaced.dropFirst()
        }
    }

    /// Builds a stable kebab-case id from a term ("Devil's advocate" -> "devils-advocate").
    static func makeID(for term: String) -> String {
        let folded = term.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "en"))
        var out = ""
        var lastWasDash = false
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar), scalar.isASCII {
                out.unicodeScalars.append(scalar)
                lastWasDash = false
            } else if scalar == "'" || scalar == "’" {
                continue // "devil's" -> "devils"
            } else if !lastWasDash, !out.isEmpty {
                out.append("-")
                lastWasDash = true
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out.lowercased()
    }
}

struct WordRoot: Codable, Hashable {
    var form: String
    var language: String?
    var meaning: String?
}

struct RelatedWord: Codable, Hashable, Identifiable {
    var term: String
    var meaning: String?
    var id: String { term }
}
