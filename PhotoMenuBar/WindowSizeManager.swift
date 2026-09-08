import AppKit
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
