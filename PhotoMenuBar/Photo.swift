import Foundation
import AppKit

struct Photo: Identifiable, Equatable {
    let id: UUID
    let image: NSImage

    init(id: UUID = UUID(), image: NSImage) {
        self.id = id
        self.image = image
    }

    static func == (lhs: Photo, rhs: Photo) -> Bool {
        lhs.id == rhs.id
    }
}
