import Foundation

/// `dailyword://entry/<id>` opens an entry's detail page; `dailyword://review` opens the review session.
enum DeepLink: Equatable {
    case entry(String)
    case review

    static let scheme = "dailyword"
    static var reviewURL: URL { URL(string: "\(scheme)://review")! }

    static func url(for entryID: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "entry"
        components.path = "/" + entryID
        return components.url ?? reviewURL
    }

    init?(url: URL) {
        guard url.scheme == DeepLink.scheme else { return nil }
        switch url.host {
        case "entry":
            let id = String(url.path.drop(while: { $0 == "/" }))
            guard !id.isEmpty else { return nil }
            self = .entry(id)
        case "review":
            self = .review
        default:
            return nil
        }
    }
}
