import Foundation
import SwiftUI

class TranscriptionStore: ObservableObject {
    @Published var transcriptions: [Transcription] = []
    @Published var isProcessing = false

    private let storageKey = "transcriptions"

    init() {
        load()
    }

    // MARK: - Entry points

    /// Transcribe an audio file at an arbitrary URL. Used by the share-extension
    /// flow and (future) by in-app recording.
    func transcribe(audioFileURL: URL) {
        guard let audioData = try? Data(contentsOf: audioFileURL) else { return }
        transcribe(audioData: audioData)
    }

    /// Picks up audio dropped by the share extension in the App Group container,
    /// deletes the shared file, and transcribes.
    func processSharedFile() {
        let fileURL = Config.sharedFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        guard let audioData = try? Data(contentsOf: fileURL) else { return }
        try? FileManager.default.removeItem(at: fileURL)
        transcribe(audioData: audioData)
    }

    // MARK: - API call

    private func transcribe(audioData: Data) {
        isProcessing = true

        var request = URLRequest(url: Config.transcribeURL)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.apiKey)", forHTTPHeaderField: "Authorization")

        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        request.timeoutInterval = 600  // 10 min — long recordings need time to trim + transcribe

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isProcessing = false

                if let error = error {
                    let item = Transcription(text: "", error: error.localizedDescription)
                    self?.transcriptions.insert(item, at: 0)
                    self?.save()
                    return
                }

                guard let data = data else {
                    let item = Transcription(text: "", error: "No data received")
                    self?.transcriptions.insert(item, at: 0)
                    self?.save()
                    return
                }

                // Adjust this parsing to match your Steno API response format
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let text = json["text"] as? String {
                    let item = Transcription(text: text)
                    self?.transcriptions.insert(item, at: 0)
                    self?.save()
                } else if let text = String(data: data, encoding: .utf8) {
                    // Fallback: treat entire response as text
                    let item = Transcription(text: text)
                    self?.transcriptions.insert(item, at: 0)
                    self?.save()
                } else {
                    let item = Transcription(text: "", error: "Could not parse response")
                    self?.transcriptions.insert(item, at: 0)
                    self?.save()
                }
            }
        }.resume()
    }

    // MARK: - Persistence (UserDefaults in App Group)

    func save() {
        let defaults = UserDefaults(suiteName: Config.appGroupID)
        if let data = try? JSONEncoder().encode(transcriptions) {
            defaults?.set(data, forKey: storageKey)
        }
    }

    private func load() {
        let defaults = UserDefaults(suiteName: Config.appGroupID)
        if let data = defaults?.data(forKey: storageKey),
           let items = try? JSONDecoder().decode([Transcription].self, from: data) {
            transcriptions = items
        }
    }
}
