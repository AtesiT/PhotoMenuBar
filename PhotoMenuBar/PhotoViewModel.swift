import Foundation
import _PhotosUI_SwiftUI
import AppKit
import Combine

@MainActor
final class PhotoViewModel: ObservableObject {
    @Published private(set) var photos: [Photo] = []
    @Published var currentIndex: Int = 0

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

    func addPhotos(from items: [PhotosPickerItem]) async {
        for item in items {
            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let nsImage = NSImage(data: data)
            else { continue }

            photos.append(Photo(image: nsImage))
        }

        if !photos.isEmpty {
            currentIndex = photos.count - 1
        }
    }

    func deleteCurrentPhoto() {
        guard let photo = currentPhoto else { return }
        photos.removeAll { $0.id == photo.id }
        if currentIndex >= photos.count {
            currentIndex = max(0, photos.count - 1)
        }
    }
}
