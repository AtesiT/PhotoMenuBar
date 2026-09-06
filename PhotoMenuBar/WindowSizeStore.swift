import Foundation

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
