import Foundation

/// A bonus word from Wiktionary's Word of the Day (CC BY-SA, no API key).
/// Tapping it runs the normal lookup, so the saved entry comes from open sources.
struct BonusWord: Codable, Equatable {
    var term: String
    var partOfSpeech: String?
    var summary: String
    var link: URL?
    var day: Int
}

struct BonusWordService {
    private static let cacheKey = "bonusWordCache.wiktionary"

    /// Fetches at most once per day; otherwise returns the cached word.
    func todaysWord(now: Date = .now) async -> BonusWord? {
        let day = Rotation.dayIndex(for: now)
        if let data = SharedConfig.defaults.data(forKey: Self.cacheKey),
           let cached = try? JSONDecoder().decode(BonusWord.self, from: data), cached.day == day {
            return cached
        }
        guard let wikitext = try? await fetchWikitext(for: now),
              let word = parse(wikitext, day: day) else { return nil }
        SharedConfig.defaults.set(try? JSONEncoder().encode(word), forKey: Self.cacheKey)
        return word
    }

    /// The day's page, e.g. "Wiktionary:Word of the day/2026/November 24".
    private func fetchWikitext(for date: Date) async throws -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MMMM d"
        var components = URLComponents(string: "https://en.wiktionary.org/w/api.php")!
        components.queryItems = [
            .init(name: "action", value: "parse"),
            .init(name: "page", value: "Wiktionary:Word of the day/\(formatter.string(from: date))"),
            .init(name: "prop", value: "wikitext"),
            .init(name: "format", value: "json"),
            .init(name: "formatversion", value: "2"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("DailyWord/1.0 (open-source vocabulary app)", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        struct Response: Decodable { struct Parse: Decodable { var wikitext: String }; var parse: Parse }
        return try JSONDecoder().decode(Response.self, from: data).parse.wikitext
    }

    /// Parses `{{WOTD|word|pos|key=value|…|definition|…|Month|Day}}`.
    func parse(_ wikitext: String, day: Int) -> BonusWord? {
        guard let start = wikitext.range(of: "{{WOTD|"), let end = wikitext.range(of: "}}", options: .backwards),
              start.upperBound < end.lowerBound else { return nil }
        var body = String(wikitext[start.upperBound..<end.lowerBound])
        // [[target|label]] → label, [[target]] → target, so "|" only separates parameters.
        body = body.replacingOccurrences(of: #"\[\[[^\]|]*\|([^\]]*)\]\]"#, with: "$1", options: .regularExpression)
        body = body.replacingOccurrences(of: #"\[\[([^\]]*)\]\]"#, with: "$1", options: .regularExpression)
        // Drop nested templates such as {{l|en|…}}.
        while body.range(of: #"\{\{[^{}]*\}\}"#, options: .regularExpression) != nil {
            body = body.replacingOccurrences(of: #"\{\{[^{}]*\}\}"#, with: "", options: .regularExpression)
        }
        let params = body.components(separatedBy: "|")
        let positional = params.filter { !$0.contains("=") }
        guard positional.count >= 3 else { return nil }
        let term = positional[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let definition = positional[2]
            .replacingOccurrences(of: "''", with: "")
            .components(separatedBy: "\n").first?   // first sense only
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !term.isEmpty else { return nil }

        let posNames = ["n": "noun", "v": "verb", "adj": "adjective", "adv": "adverb", "prep": "preposition",
                        "interj": "interjection", "phrase": "phrase", "prop": "proper noun", "pn": "proper noun",
                        "idiom": "idiom", "conj": "conjunction"]
        let pos = positional[1].trimmingCharacters(in: .whitespaces)
        let link = term.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            .flatMap { URL(string: "https://en.wiktionary.org/wiki/\($0.replacingOccurrences(of: "%20", with: "_"))") }
        return BonusWord(term: term, partOfSpeech: posNames[pos] ?? pos, summary: String(definition.prefix(300)),
                         link: link, day: day)
    }
}
