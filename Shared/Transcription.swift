import Foundation

struct Transcription: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let filename: String?
    let title: String?
    let description: String?
    let text: String
    let cleanedPolished: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, filename, title, description, text
        case cleanedPolished = "cleaned_polished"
        case createdAt = "created_at"
    }

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        if let filename, !filename.isEmpty { return filename }
        return "Untitled"
    }

    var hasPolishedVariant: Bool {
        cleanedPolished?.isEmpty == false
    }
}
