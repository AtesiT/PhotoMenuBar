import Foundation
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

    func addTestPhoto() {
        // Создаём простую цветную заглушку-картинку для проверки UI
        let size = NSSize(width: 200, height: 200)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.withAlphaComponent(Double.random(in: 0.3...1.0)).setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        photos.append(Photo(image: image))
        currentIndex = photos.count - 1
    }

    func deleteCurrentPhoto() {
        guard let photo = currentPhoto else { return }
        photos.removeAll { $0.id == photo.id }
        if currentIndex >= photos.count {
            currentIndex = max(0, photos.count - 1)
        }
    }
}
