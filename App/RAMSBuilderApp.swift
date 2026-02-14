import SwiftUI

@main
struct RAMSBuilderApp: App {
    @StateObject private var sessionViewModel: SessionViewModel
    @StateObject private var libraryViewModel: LibraryViewModel

    init() {
        let authService = MockAuthService()
        let libraryStore = LibraryStore()
        _sessionViewModel = StateObject(wrappedValue: SessionViewModel(authService: authService))
        _libraryViewModel = StateObject(wrappedValue: LibraryViewModel(store: libraryStore))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(sessionViewModel)
                .environmentObject(libraryViewModel)
        }
    }
}
