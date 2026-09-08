import AppKit

final class FloatingPanel: NSPanel {
    init(contentRect: NSRect, viewController: NSViewController) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        self.contentViewController = viewController
        self.isMovableByWindowBackground = false
        self.level = .floating
        self.hasShadow = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
