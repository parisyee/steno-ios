import Foundation

struct Transcription: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let filename: String?
    let title: String?
    let description: String?
    let text: String
    let cleaned: Cleaned?
    let createdAt: Date

    struct Cleaned: Codable, Equatable, Hashable {
        let light: String?
        let polished: String?
    }

    enum CodingKeys: String, CodingKey {
        case id, filename, title, description, text, cleaned
        case createdAt = "created_at"
    }

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        if let filename, !filename.isEmpty { return filename }
        return "Untitled"
    }

    var hasCleanedVariants: Bool {
        (cleaned?.light?.isEmpty == false) || (cleaned?.polished?.isEmpty == false)
    }
}
