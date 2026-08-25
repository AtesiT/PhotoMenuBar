import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let viewModel = PhotoViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // приложение не в Dock

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "photo.on.rectangle",
                accessibilityDescription: "Photo Manager"
            )
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 420)
        // Ключевая строка: popover не закрывается автоматически при потере фокуса
        popover.behavior = .applicationDefined
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(viewModel)
        )
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
