import Foundation

/// The bundled, read-only curated entries (Resources/Words/*.json).
final class WordLibrary {
    static let shared = WordLibrary()

    let entries: [Entry]
    let byID: [String: Entry]
    /// IDs in daily-rotation order.
    let rotation: [String]
    let categories: [String]

    init(bundle: Bundle = .main) {
        var loaded: [Entry] = []
        let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Words") ?? []
        let decoder = JSONDecoder()
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            do {
                let data = try Data(contentsOf: url)
                loaded += try decoder.decode([Entry].self, from: data)
            } catch {
                SharedConfig.logger.error("Failed to load \(url.lastPathComponent): \(String(describing: error))")
            }
        }
        var byID: [String: Entry] = [:]
        var unique: [Entry] = []
        for entry in loaded where byID[entry.id] == nil {
            byID[entry.id] = entry
            unique.append(entry)
        }
        self.entries = unique.sorted { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
        self.byID = byID
        self.rotation = Rotation.order(unique.map(\.id))
        self.categories = Array(Set(unique.map(\.category))).sorted()
    }

    /// Finds a curated entry by its display term (case-insensitive).
    func entry(matchingTerm term: String) -> Entry? {
        byID[Entry.makeID(for: term)]
    }
}
