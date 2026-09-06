import AppKit

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
