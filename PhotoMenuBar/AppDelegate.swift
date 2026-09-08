import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var floatingPanel: FloatingPanel!
    private let viewModel = PhotoViewModel()
    private var sizeManager: WindowSizeManager!

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

        let initialSize = WindowSizeStore.load() ?? CGSize(width: 360, height: 320)
        let initialOrigin = WindowPositionStore.load() ?? NSPoint(x: 100, y: 100)

        sizeManager = WindowSizeManager(initialSize: initialSize)

        let hostingController = NSHostingController(
            rootView: ContentView()
                .environmentObject(viewModel)
                .environmentObject(sizeManager)
        )

        let contentRect = NSRect(origin: initialOrigin, size: initialSize)
        floatingPanel = FloatingPanel(contentRect: contentRect, viewController: hostingController)
        sizeManager.attach(window: floatingPanel)
    }

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        if floatingPanel.isVisible {
            floatingPanel.orderOut(nil)
        } else {
            positionPanelNearStatusItemIfNeeded()
            floatingPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func positionPanelNearStatusItemIfNeeded() {
        guard
            WindowPositionStore.load() == nil,
            let button = statusItem.button,
            let buttonWindow = button.window
        else { return }

        let buttonFrameInScreen = buttonWindow.convertToScreen(button.frame)
        let panelSize = floatingPanel.frame.size
        let origin = NSPoint(
            x: buttonFrameInScreen.midX - panelSize.width / 2,
            y: buttonFrameInScreen.minY - panelSize.height - 4
        )
        floatingPanel.setFrameOrigin(origin)
    }

    private func showContextMenu() {
        if floatingPanel.isVisible {
            floatingPanel.orderOut(nil)
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
        let openPanel = NSOpenPanel()
        openPanel.title = "Выберите фото"
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.image]

        openPanel.begin { [weak self] response in
            guard response == .OK, let self else { return }
            let urls = openPanel.urls
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
