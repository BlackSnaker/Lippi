import SwiftUI

@main
struct LippiWatchApp: App {
    @StateObject private var care = WatchCareStore()

    var body: some Scene {
        WindowGroup {
            WatchCareView()
                .environmentObject(care)
        }
    }
}
