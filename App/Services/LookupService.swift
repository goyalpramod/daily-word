import Foundation

/// Looks up a word or phrase using two free, keyless sources:
///  - dictionaryapi.dev: definition, pronunciation, example, synonyms (good for single words)
///  - Wiktionary: etymology and related terms (and a definition fallback for phrases)
/// The result is a *draft* the user can edit before saving.
struct LookupService {
    enum LookupError: LocalizedError {
        case notFound
        var errorDescription: String? { "Couldn't find that word. You can still fill it in yourself." }
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        // Wikimedia asks API clients to identify themselves with a descriptive User-Agent.
        config.httpAdditionalHeaders = ["User-Agent": "DailyWord/1.0 (open-source vocabulary app)"]
        return URLSession(configuration: config)
    }()

    func lookUp(_ rawTerm: String) async throws -> Entry {
        let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        async let dictionary = try? fetchDictionaryAPI(term)
        async let wiktionary = try? fetchWiktionary(term)
        let (dict, wiki) = await (dictionary, wiktionary)

        guard dict != nil || wiki?.definition != nil else { throw LookupError.notFound }

        let isPhrase = term.contains(" ")
        return Entry(
            id: "",
            term: dict?.term ?? term,
            kind: isPhrase ? .phrase : .word,
            partOfSpeech: dict?.partOfSpeech ?? wiki?.partOfSpeech,
            pronunciation: dict?.phonetic,
            definition: dict?.definition ?? wiki?.definition ?? "",
            example: dict?.example ?? wiki?.example,
            etymology: wiki?.etymology,
            root: nil,
            relatedWords: wiki?.related?.map { RelatedWord(term: $0, meaning: nil) },
            synonyms: dict?.synonyms,
            note: nil,
            category: Entry.customCategory
        )
    }

    // MARK: - dictionaryapi.dev

    private struct DictResult {
        var term: String
        var phonetic: String?
        var partOfSpeech: String?
        var definition: String?
        var example: String?
        var synonyms: [String]?
    }

    private struct DictEntry: Decodable {
        struct Phonetic: Decodable { var text: String? }
        struct Meaning: Decodable {
            struct Definition: Decodable { var definition: String; var example: String? }
            var partOfSpeech: String
            var definitions: [Definition]
            var synonyms: [String]?
        }
        var word: String
        var phonetic: String?
        var phonetics: [Phonetic]?
        var meanings: [Meaning]
    }

    private func fetchDictionaryAPI(_ term: String) async throws -> DictResult {
        let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? term
        let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)")!
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw LookupError.notFound }
        let entries = try JSONDecoder().decode([DictEntry].self, from: data)
        guard let first = entries.first, let meaning = first.meanings.first else { throw LookupError.notFound }

        let allDefs = entries.flatMap(\.meanings).flatMap(\.definitions)
        let synonyms = Array(entries.flatMap(\.meanings).flatMap { $0.synonyms ?? [] }.uniqued().prefix(4))
        return DictResult(
            term: first.word,
            phonetic: first.phonetic ?? first.phonetics?.compactMap(\.text).first,
            partOfSpeech: meaning.partOfSpeech,
            definition: meaning.definitions.first?.definition,
            example: allDefs.compactMap(\.example).first,
            synonyms: synonyms.isEmpty ? nil : synonyms
        )
    }

    // MARK: - Wiktionary

    private struct WikiResult {
        var partOfSpeech: String?
        var definition: String?
        var example: String?
        var etymology: String?
        var related: [String]?
    }

    private func fetchWiktionary(_ term: String) async throws -> WikiResult {
        // Wiktionary titles are case-sensitive; most entries are lowercase.
        var candidates = [term]
        if term.lowercased() != term { candidates.append(term.lowercased()) }

        for title in candidates {
            guard let sections = try? await wikiSections(title) else { continue }
            async let etymology = sections.etymology.asyncMap { try? await wikiSectionText(title, index: $0) }
            async let related = sections.related.asyncMap { try? await wikiSectionListItems(title, index: $0) }
            async let definition = try? await wikiDefinition(title)
            let (ety, rel, def) = await (etymology, related, definition)
            return WikiResult(
                partOfSpeech: def?.partOfSpeech,
                definition: def?.definition,
                example: def?.example,
                etymology: ety.flatMap { $0 }.flatMap { $0.isEmpty ? nil : $0 },
                related: rel.flatMap { $0 }.flatMap { $0.isEmpty ? nil : $0 }
            )
        }
        throw LookupError.notFound
    }

    private struct SectionIndexes { var etymology: String?; var related: String? }

    private func wikiSections(_ title: String) async throws -> SectionIndexes {
        struct Response: Decodable {
            struct Parse: Decodable {
                struct Section: Decodable { var level: String; var line: String; var index: String }
                var sections: [Section]
            }
            var parse: Parse
        }
        let data = try await wikiAPI(["action": "parse", "page": title, "prop": "sections", "redirects": "1"])
        let sections = try JSONDecoder().decode(Response.self, from: data).parse.sections

        // Only look inside the "English" language section.
        guard let englishStart = sections.firstIndex(where: { $0.level == "2" && $0.line == "English" }) else {
            throw LookupError.notFound
        }
        let rest = sections[(englishStart + 1)...]
        let english = rest.prefix { $0.level != "2" }
        return SectionIndexes(
            etymology: english.first { $0.line.hasPrefix("Etymology") }?.index,
            related: english.first { $0.line == "Related terms" || $0.line == "Derived terms" }?.index
        )
    }

    private func wikiSectionHTML(_ title: String, index: String) async throws -> String {
        struct Response: Decodable { struct Parse: Decodable { var text: String }; var parse: Parse }
        let data = try await wikiAPI(["action": "parse", "page": title, "section": index, "prop": "text",
                                      "redirects": "1", "disableeditsection": "1"])
        return try JSONDecoder().decode(Response.self, from: data).parse.text
    }

    private func wikiSectionText(_ title: String, index: String) async throws -> String {
        let html = try await wikiSectionHTML(title, index: index)
            .removingMatches(of: #"<sup[\s\S]*?</sup>"#)       // footnote markers
            .removingMatches(of: #"<style[\s\S]*?</style>"#)
        // The prose lives in <p> tags; etymology-tree widgets, reference lists and
        // headings live in <div>/<ol>/<h*>, so taking only paragraphs skips them.
        let regex = try NSRegularExpression(pattern: #"<p>([\s\S]*?)</p>"#)
        let paragraphs = regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap {
            Range($0.range(at: 1), in: html).map { String(html[$0]).strippingHTML() }
        }.filter { !$0.isEmpty }
        let text = paragraphs.joined(separator: "\n")
        // Keep it readable: the first few sentences are the useful part.
        return String(text.prefix(700))
    }

    private func wikiSectionListItems(_ title: String, index: String) async throws -> [String] {
        let html = try await wikiSectionHTML(title, index: index)
        let regex = try NSRegularExpression(pattern: #"<li[^>]*>([\s\S]*?)</li>"#)
        let range = NSRange(html.startIndex..., in: html)
        let items = regex.matches(in: html, range: range).compactMap { match -> String? in
            guard let r = Range(match.range(at: 1), in: html) else { return nil }
            let text = String(html[r]).strippingHTML()
            // "word (gloss)" -> "word"
            let word = text.components(separatedBy: CharacterSet(charactersIn: "(:,;")).first?
                .trimmingCharacters(in: .whitespaces) ?? ""
            return word.isEmpty || word.count > 40 ? nil : word
        }
        return Array(items.uniqued().prefix(8))
    }

    private func wikiDefinition(_ title: String) async throws -> (partOfSpeech: String, definition: String, example: String?) {
        struct Response: Decodable {
            struct Usage: Decodable {
                struct Def: Decodable {
                    struct Example: Decodable { var example: String }
                    var definition: String
                    var parsedExamples: [Example]?
                }
                var partOfSpeech: String
                var definitions: [Def]
            }
            var en: [Usage]?
        }
        let encoded = title.replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        let url = URL(string: "https://en.wiktionary.org/api/rest_v1/page/definition/\(encoded)")!
        let (data, _) = try await session.data(from: url)
        let usage = try JSONDecoder().decode(Response.self, from: data).en ?? []
        for u in usage {
            for def in u.definitions {
                let text = def.definition.strippingHTML()
                if !text.isEmpty {
                    return (u.partOfSpeech.lowercased(), text, def.parsedExamples?.first?.example.strippingHTML())
                }
            }
        }
        throw LookupError.notFound
    }

    private func wikiAPI(_ params: [String: String]) async throws -> Data {
        var components = URLComponents(string: "https://en.wiktionary.org/w/api.php")!
        components.queryItems = (params.merging(["format": "json", "formatversion": "2"]) { a, _ in a })
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        let (data, response) = try await session.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw LookupError.notFound }
        return data
    }
}

// MARK: - Small helpers

extension String {
    /// Turns a snippet of HTML into plain text.
    func strippingHTML() -> String {
        var s = self.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: #"</p>"#, with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'",
                        "&nbsp;": " ", "&#149;": "•", "&#160;": " ", "&#8212;": "—", "&#8211;": "–"]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        s = s.decodingNumericEntities()
        s = s.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s*\n\s*"#, with: "\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "&#42;" -> "*", "&#x2014;" -> "—"
    func decodingNumericEntities() -> String {
        guard let regex = try? NSRegularExpression(pattern: #"&#(x?)([0-9a-fA-F]+);"#) else { return self }
        var result = self
        for match in regex.matches(in: self, range: NSRange(startIndex..., in: self)).reversed() {
            guard let whole = Range(match.range, in: result),
                  let hexFlag = Range(match.range(at: 1), in: result),
                  let digits = Range(match.range(at: 2), in: result),
                  let code = UInt32(result[digits], radix: result[hexFlag].isEmpty ? 10 : 16),
                  let scalar = Unicode.Scalar(code) else { continue }
            result.replaceSubrange(whole, with: String(Character(scalar)))
        }
        return result
    }

    func removingMatches(of pattern: String) -> String {
        replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
}

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Optional {
    func asyncMap<T>(_ transform: (Wrapped) async -> T) async -> T? {
        guard let value = self else { return nil }
        return await transform(value)
    }
}
