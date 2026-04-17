import Foundation

struct Transcription: Identifiable, Codable {
    let id: UUID
    let date: Date
    let text: String
    let error: String?

    init(text: String, error: String? = nil) {
        self.id = UUID()
        self.date = Date()
        self.text = text
        self.error = error
    }
}
