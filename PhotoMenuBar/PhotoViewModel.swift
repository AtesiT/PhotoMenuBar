import Foundation
import AppKit
import Combine

@MainActor
final class PhotoViewModel: ObservableObject {
    @Published private(set) var photos: [Photo] = []
    @Published var currentIndex: Int = 0
    @Published var isLoading: Bool = false

    private let fileManager = FileManager.default
    private let imageCache = NSCache<NSString, NSImage>()

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
        loadMetadata()
    }

    var currentPhoto: Photo? {
        guard photos.indices.contains(currentIndex) else { return nil }
        return photos[currentIndex]
    }

    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex < photos.count - 1 }

    func goBack() {
        guard canGoBack else { return }
        currentIndex -= 1
    }

    func goForward() {
        guard canGoForward else { return }
        currentIndex += 1
    }

    func image(for photo: Photo) -> NSImage? {
        let key = photo.fileName as NSString

        if let cached = imageCache.object(forKey: key) {
            return cached
        }

        let url = imagesDirectory.appendingPathComponent(photo.fileName)
        guard let image = NSImage(contentsOf: url) else {
            return nil
        }

        imageCache.setObject(image, forKey: key)
        return image
    }

    func addPhotos(from urls: [URL]) async {
        isLoading = true
        defer { isLoading = false }

        for url in urls {
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            guard let data = try? Data(contentsOf: url) else { continue }

            let fileExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            let fileName = UUID().uuidString + "." + fileExtension
            let destinationURL = imagesDirectory.appendingPathComponent(fileName)

            do {
                try data.write(to: destinationURL)
                photos.append(Photo(fileName: fileName))
            } catch {
                print("Ошибка копирования файла из Finder: \(error)")
            }
        }

        if !photos.isEmpty {
            currentIndex = photos.count - 1
        }
        saveMetadata()
    }

    func deleteCurrentPhoto() {
        guard let photo = currentPhoto else { return }

        let url = imagesDirectory.appendingPathComponent(photo.fileName)
        try? fileManager.removeItem(at: url)
        imageCache.removeObject(forKey: photo.fileName as NSString)

        photos.removeAll { $0.id == photo.id }

        if currentIndex >= photos.count {
            currentIndex = max(0, photos.count - 1)
        }
        saveMetadata()
    }

    private func saveMetadata() {
        do {
            let data = try JSONEncoder().encode(photos)
            try data.write(to: metadataURL)
        } catch {
            print("Ошибка сохранения метаданных: \(error)")
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
            print("Ошибка загрузки метаданных: \(error)")
        }
    }
}
