import AppKit
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import Combine

struct Photo: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String

    init(id: UUID = UUID(), fileName: String) {
        self.id = id
        self.fileName = fileName
    }
}

@MainActor
final class PhotoViewModel: ObservableObject {
    @Published private(set) var photos: [Photo] = []
    @Published var currentIndex: Int = 0 {
        didSet {
            prefetchNeighbors()
        }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let fileManager = FileManager.default
    private let imageCache = NSCache<NSString, NSImage>()
    private let maxDisplaySize: CGFloat = 900

    private var appSupportDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory,
                                     in: .userDomainMask).first!
        let dir = base.appendingPathComponent("PhotoMenuBarApp", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var imagesDirectory: URL {
        let dir = appSupportDirectory.appendingPathComponent("Images", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var metadataURL: URL {
        appSupportDirectory.appendingPathComponent("photos.json")
    }

    init() {
        imageCache.countLimit = 30
        imageCache.totalCostLimit = 150 * 1024 * 1024
        loadMetadata()
    }

    var currentPhoto: Photo? {
        guard photos.indices.contains(currentIndex) else { return nil }
        return photos[currentIndex]
    }

    var canGoBack: Bool { photos.count > 1 }
    var canGoForward: Bool { photos.count > 1 }

    func goBack() {
        guard photos.count > 1 else { return }
        currentIndex = (currentIndex - 1 + photos.count) % photos.count
    }

    func goForward() {
        guard photos.count > 1 else { return }
        currentIndex = (currentIndex + 1) % photos.count
    }

    func image(for photo: Photo) -> NSImage? {
        let key = photo.fileName as NSString

        if let cached = imageCache.object(forKey: key) {
            return cached
        }

        let url = imagesDirectory.appendingPathComponent(photo.fileName)
        guard let image = Self.downsampledImage(at: url, maxPixelSize: maxPixelSize) else {
            return nil
        }

        imageCache.setObject(image, forKey: key, cost: cacheCost(for: image))
        return image
    }

    func prefetchNeighbors() {
        guard photos.count > 1 else { return }

        let nextIndex = (currentIndex + 1) % photos.count
        let previousIndex = (currentIndex - 1 + photos.count) % photos.count
        let pixelSize = maxPixelSize
        let dir = imagesDirectory

        for index in [nextIndex, previousIndex] {
            let photo = photos[index]
            let key = photo.fileName as NSString

            if imageCache.object(forKey: key) != nil { continue }

            let url = dir.appendingPathComponent(photo.fileName)

            Task.detached(priority: .utility) { [weak self] in
                guard let image = Self.downsampledImage(at: url, maxPixelSize: pixelSize) else { return }

                await MainActor.run {
                    guard let self else { return }
                    if self.imageCache.object(forKey: key) == nil {
                        self.imageCache.setObject(image, forKey: key, cost: self.cacheCost(for: image))
                    }
                }
            }
        }
    }

    private var maxPixelSize: CGFloat {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        return maxDisplaySize * scale
    }

    nonisolated private static func downsampledImage(at url: URL, maxPixelSize: CGFloat) -> NSImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, thumbnailOptions as CFDictionary
        ) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private func cacheCost(for image: NSImage) -> Int {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return 0
        }
        return cgImage.bytesPerRow * cgImage.height
    }

    func addPhotos(from urls: [URL]) async {
        isLoading = true
        defer { isLoading = false }

        var failedFileNames: [String] = []

        for url in urls {
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            guard let data = try? Data(contentsOf: url) else {
                failedFileNames.append(url.lastPathComponent)
                continue
            }

            let fileExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            let fileName = UUID().uuidString + "." + fileExtension
            let destinationURL = imagesDirectory.appendingPathComponent(fileName)

            do {
                try data.write(to: destinationURL)
                photos.append(Photo(fileName: fileName))
            } catch {
                failedFileNames.append(url.lastPathComponent)
            }
        }

        if !photos.isEmpty {
            currentIndex = photos.count - 1
        }
        saveMetadata()

        if !failedFileNames.isEmpty {
            let names = failedFileNames.joined(separator: ", ")
            errorMessage = "Не удалось добавить: \(names)"
        }
    }

    func deleteCurrentPhoto() {
        guard let photo = currentPhoto else { return }

        let url = imagesDirectory.appendingPathComponent(photo.fileName)

        do {
            try fileManager.removeItem(at: url)
        } catch {
            errorMessage = "Не удалось удалить файл: \(error.localizedDescription)"
        }

        imageCache.removeObject(forKey: photo.fileName as NSString)

        photos.removeAll { $0.id == photo.id }

        if currentIndex >= photos.count {
            currentIndex = max(0, photos.count - 1)
        }
        saveMetadata()
        prefetchNeighbors()
    }

    private func saveMetadata() {
        do {
            let data = try JSONEncoder().encode(photos)
            try data.write(to: metadataURL)
        } catch {
            errorMessage = "Не удалось сохранить данные: \(error.localizedDescription)"
        }
    }

    private func loadMetadata() {
        guard fileManager.fileExists(atPath: metadataURL.path) else { return }
        do {
            let data = try Data(contentsOf: metadataURL)
            let loaded = try JSONDecoder().decode([Photo].self, from: data)

            photos = loaded.filter { photo in
                let url = imagesDirectory.appendingPathComponent(photo.fileName)
                return fileManager.fileExists(atPath: url.path)
            }

            currentIndex = 0

            if photos.count != loaded.count {
                saveMetadata()
            }
        } catch {
            errorMessage = "Не удалось загрузить данные: \(error.localizedDescription)"
        }
    }
}

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
        let rawInitialOrigin = WindowPositionStore.load() ?? NSPoint(x: 100, y: 100)
        let initialOrigin = WindowPositionStore.clamped(rawInitialOrigin, windowSize: initialSize)

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
            ensurePanelOnScreen()
            floatingPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func ensurePanelOnScreen() {
        let clamped = WindowPositionStore.clamped(
            floatingPanel.frame.origin,
            windowSize: floatingPanel.frame.size
        )
        if clamped != floatingPanel.frame.origin {
            floatingPanel.setFrameOrigin(clamped)
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

@main
struct PhotoMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
