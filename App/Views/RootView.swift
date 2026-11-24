import SwiftUI

struct RootView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "text.book.closed") }
                .tag(Router.Tab.today)
            ReviewView()
                .tabItem { Label("Review", systemImage: "rectangle.stack") }
                .tag(Router.Tab.review)
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(Router.Tab.library)
        }
    }
}
