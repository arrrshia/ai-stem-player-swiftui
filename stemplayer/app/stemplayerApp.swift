import SwiftUI
import SwiftData

@main
struct StemPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: StemFolder.self)
        }
    }
}
