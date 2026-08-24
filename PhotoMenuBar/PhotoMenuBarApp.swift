import SwiftUI

@main
struct PhotoMenuBarApp: App {
    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Image(systemName: "photo.on.rectangle")
        }
        .menuBarExtraStyle(.window)
    }
}
