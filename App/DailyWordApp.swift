import SwiftUI
import SwiftData
import CoreData

@main
struct DailyWordApp: App {
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .onOpenURL { url in
                    if let link = DeepLink(url: url) { router.open(link) }
                }
                // When iCloud brings in changes from your other device, refresh the widgets.
                .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
                    .debounce(for: .seconds(2), scheduler: RunLoop.main)) { _ in
                    Vocab.reloadWidgets()
                }
        }
        .modelContainer(DataStore.container)
        #if os(macOS)
        .defaultSize(width: 760, height: 680)
        #endif
    }
}

/// Simple app-wide navigation state, so deep links from widgets can switch tabs
/// and push an entry's detail page.
@Observable
final class Router {
    enum Tab: Hashable { case today, review, library }

    var tab: Tab = .today
    var todayPath = NavigationPath()

    func open(_ link: DeepLink) {
        switch link {
        case .entry(let id):
            tab = .today
            todayPath = NavigationPath()
            todayPath.append(EntryRoute(id: id))
        case .review:
            tab = .review
        }
    }
}

struct EntryRoute: Hashable {
    let id: String
}
