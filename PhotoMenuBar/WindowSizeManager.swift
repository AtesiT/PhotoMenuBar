import AppKit
import SwiftUI
import Combine

@MainActor
final class WindowSizeManager: ObservableObject {
    @Published private(set) var currentSize: CGSize

    private weak var window: NSWindow?

    private let minSize = CGSize(width: 260, height: 240)
    private let maxSize = CGSize(width: 900, height: 900)

    init(initialSize: CGSize) {
        self.currentSize = initialSize
    }

    func attach(window: NSWindow) {
        self.window = window
    }

    func updateSize(deltaWidth: CGFloat, deltaHeight: CGFloat) {
        guard let window else { return }

        let oldFrame = window.frame
        let topLeftY = oldFrame.origin.y + oldFrame.size.height

        var newSize = currentSize
        newSize.width = clamp(newSize.width + deltaWidth, min: minSize.width, max: maxSize.width)
        newSize.height = clamp(newSize.height + deltaHeight, min: minSize.height, max: maxSize.height)

        guard newSize != currentSize else { return }
        currentSize = newSize

        let newOrigin = NSPoint(x: oldFrame.origin.x, y: topLeftY - newSize.height)
        window.setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
    }

    func commitSize() {
        guard let window else { return }
        WindowSizeStore.save(currentSize)
        WindowPositionStore.save(window.frame.origin)
    }

    private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
}

final class DraggableNSView: NSView {
    private var initialLocationInWindow: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        initialLocationInWindow = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else { return }

        let screenLocation = NSEvent.mouseLocation
        let newOrigin = NSPoint(
            x: screenLocation.x - initialLocationInWindow.x,
            y: screenLocation.y - initialLocationInWindow.y
        )
        window.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        guard let window = self.window else { return }
        WindowPositionStore.save(window.frame.origin)
    }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableNSView {
        DraggableNSView()
    }

    func updateNSView(_ nsView: DraggableNSView, context: Context) {}
}

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

enum WindowSizeStore {
    private static let key = "PopoverWindowSize"

    static func save(_ size: CGSize) {
        let dict: [String: CGFloat] = ["width": size.width, "height": size.height]
        UserDefaults.standard.set(dict, forKey: key)
    }

    static func load() -> CGSize? {
        guard
            let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: CGFloat],
            let width = dict["width"],
            let height = dict["height"]
        else {
            return nil
        }
        return CGSize(width: width, height: height)
    }
}

enum WindowPositionStore {
    private static let key = "PopoverWindowOrigin"

    static func save(_ origin: NSPoint) {
        let dict: [String: CGFloat] = ["x": origin.x, "y": origin.y]
        UserDefaults.standard.set(dict, forKey: key)
    }

    static func load() -> NSPoint? {
        guard
            let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: CGFloat],
            let x = dict["x"],
            let y = dict["y"]
        else {
            return nil
        }
        return NSPoint(x: x, y: y)
    }

    static func clamped(_ origin: NSPoint, windowSize: NSSize) -> NSPoint {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(origin) }) ?? NSScreen.main

        guard let visibleFrame = screen?.visibleFrame else { return origin }

        var result = origin
        result.x = min(max(result.x, visibleFrame.minX), visibleFrame.maxX - windowSize.width)
        result.y = min(max(result.y, visibleFrame.minY), visibleFrame.maxY - windowSize.height)
        return result
    }
}

