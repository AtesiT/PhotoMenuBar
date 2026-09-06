import AppKit
import Combine

@MainActor
final class PopoverSizeManager: ObservableObject {
    @Published private(set) var currentSize: CGSize

    private weak var popover: NSPopover?

    private let minSize = CGSize(width: 260, height: 240)
    private let maxSize = CGSize(width: 900, height: 900)

    init(popover: NSPopover, initialSize: CGSize) {
        self.popover = popover
        self.currentSize = initialSize
    }

    func updateSize(deltaWidth: CGFloat, deltaHeight: CGFloat) {
        guard
            let popover,
            let window = popover.contentViewController?.view.window
        else { return }

        let oldFrame = window.frame
        let topLeft = NSPoint(x: oldFrame.origin.x, y: oldFrame.origin.y + oldFrame.size.height)

        var newSize = currentSize
        newSize.width = clamp(newSize.width + deltaWidth, min: minSize.width, max: maxSize.width)
        newSize.height = clamp(newSize.height + deltaHeight, min: minSize.height, max: maxSize.height)

        guard newSize != currentSize else { return }
        currentSize = newSize

        popover.animates = false
        popover.contentSize = newSize

        let newOrigin = NSPoint(x: topLeft.x, y: topLeft.y - newSize.height)
        window.setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
    }

    func commitSize() {
        WindowSizeStore.save(currentSize)
        popover?.animates = true
    }

    private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
}
