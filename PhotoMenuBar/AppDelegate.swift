import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let viewModel = PhotoViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "photo.on.rectangle",
                accessibilityDescription: "Photo Manager"
            )
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 320)
        popover.behavior = .applicationDefined
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(viewModel)
        )
    }

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()

            if let savedOrigin = WindowPositionStore.load() {
                DispatchQueue.main.async { [weak self] in
                    guard let self, let window = self.popover.contentViewController?.view.window else { return }
                    let safeOrigin = WindowPositionStore.clamped(savedOrigin, windowSize: window.frame.size)
                    window.setFrameOrigin(safeOrigin)
                }
            }
        }
    }

    private func showContextMenu() {
        if popover.isShown {
            popover.performClose(nil)
        }

        let menu = NSMenu()

        let addItem = NSMenuItem(
            title: "Добавить фото…",
            action: #selector(addPhotoAction),
            keyEquivalent: ""
        )
        addItem.target = self
        menu.addItem(addItem)

        let deleteItem = NSMenuItem(
            title: "Удалить текущее фото",
            action: #selector(deletePhotoAction),
            keyEquivalent: ""
        )
        deleteItem.target = self
        deleteItem.isEnabled = viewModel.currentPhoto != nil
        menu.addItem(deleteItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Выход",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func addPhotoAction() {
        let panel = NSOpenPanel()
        panel.title = "Выберите фото"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        panel.begin { [weak self] response in
            guard response == .OK, let self else { return }
            let urls = panel.urls
            Task { @MainActor in
                await self.viewModel.addPhotos(from: urls)
            }
        }
    }

    @objc private func deletePhotoAction() {
        Task { @MainActor in
            viewModel.deleteCurrentPhoto()
        }
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
