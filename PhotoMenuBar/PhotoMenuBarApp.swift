import SwiftUI

@main
struct PhotoMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Реальный UI строится через NSPopover в AppDelegate
        Settings {
            EmptyView()
        }
    }
}
