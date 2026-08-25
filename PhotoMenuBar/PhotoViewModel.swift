import Foundation
import _PhotosUI_SwiftUI
import AppKit
import PhotosUI
import Combine

@MainActor
final class PhotoViewModel: ObservableObject {
    @Published private(set) var photos: [Photo] = []
    @Published var currentIndex: Int = 0

    private let fileManager = FileManager.default

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
        let url = imagesDirectory.appendingPathComponent(photo.fileName)
        return NSImage(contentsOf: url)
    }

    func addPhotos(from items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }

            let fileName = UUID().uuidString + ".jpg"
            let url = imagesDirectory.appendingPathComponent(fileName)

            if let nsImage = NSImage(data: data),
               let tiff = nsImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
                try? jpegData.write(to: url)
            } else {
                try? data.write(to: url)
            }

            photos.append(Photo(fileName: fileName))
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
            photos = try JSONDecoder().decode([Photo].self, from: data)
            currentIndex = 0
        } catch {
            print("Ошибка загрузки метаданных: \(error)")
        }
    }
}
