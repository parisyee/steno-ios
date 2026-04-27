import Foundation
import SwiftUI

@MainActor
class TranscriptionStore: ObservableObject {
    @Published var transcriptions: [Transcription] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isProcessing = false
    @Published var hasMore = true
    @Published var lastError: String?

    private let api = APIClient.shared
    private let storageKey = "transcriptions.v2"
    private let pageSize = 20

    init() {
        loadCache()
    }

    // MARK: - List / refresh / pagination

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await api.list(limit: pageSize, offset: 0)
            transcriptions = page
            hasMore = page.count == pageSize
            saveCache()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadMoreIfNeeded(current item: Transcription) async {
        guard hasMore, !isLoadingMore else { return }
        guard let idx = transcriptions.firstIndex(of: item) else { return }
        if idx >= transcriptions.count - 4 {
            await loadMore()
        }
    }

    private func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await api.list(limit: pageSize, offset: transcriptions.count)
            let known = Set(transcriptions.map(\.id))
            let fresh = page.filter { !known.contains($0.id) }
            transcriptions.append(contentsOf: fresh)
            hasMore = page.count == pageSize
            saveCache()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Delete

    func delete(_ item: Transcription) async {
        guard let idx = transcriptions.firstIndex(of: item) else { return }
        let removed = transcriptions.remove(at: idx)
        saveCache()
        do {
            try await api.delete(id: removed.id)
        } catch {
            transcriptions.insert(removed, at: idx)
            saveCache()
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Transcribe (share-extension entry points)

    func processSharedFile(polish: Bool = false) {
        let fileURL = Config.sharedFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        runTranscribe(audioFileURL: fileURL, deleteAfter: true, polish: polish)
    }

    func transcribe(audioFileURL: URL, polish: Bool = false) {
        runTranscribe(audioFileURL: audioFileURL, deleteAfter: false, polish: polish)
    }

    private func runTranscribe(audioFileURL: URL, deleteAfter: Bool, polish: Bool) {
        Task {
            isProcessing = true
            defer {
                isProcessing = false
                if deleteAfter {
                    try? FileManager.default.removeItem(at: audioFileURL)
                }
            }
            do {
                let new = try await api.transcribe(audioFileURL: audioFileURL, polish: polish)
                if !transcriptions.contains(where: { $0.id == new.id }) {
                    transcriptions.insert(new, at: 0)
                }
                saveCache()
            } catch {
                lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - Cache (UserDefaults in App Group)

    private func saveCache() {
        let defaults = UserDefaults(suiteName: Config.appGroupID)
        if let data = try? JSONEncoder.cache.encode(transcriptions) {
            defaults?.set(data, forKey: storageKey)
        }
    }

    private func loadCache() {
        let defaults = UserDefaults(suiteName: Config.appGroupID)
        guard let data = defaults?.data(forKey: storageKey) else { return }
        if let items = try? JSONDecoder.cache.decode([Transcription].self, from: data) {
            transcriptions = items
        }
    }
}

private extension JSONEncoder {
    static let cache: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let cache: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
