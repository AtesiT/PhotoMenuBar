import AppKit
import SwiftUI

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
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableNSView {
        DraggableNSView()
    }

    func updateNSView(_ nsView: DraggableNSView, context: Context) {}
}
