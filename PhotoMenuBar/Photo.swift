import Foundation

struct Photo: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String

    init(id: UUID = UUID(), fileName: String) {
        self.id = id
        self.fileName = fileName
    }
}
