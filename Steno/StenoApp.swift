import SwiftUI

@main
struct StenoApp: App {
    @StateObject private var transcriptionStore = TranscriptionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(transcriptionStore)
                .onOpenURL { url in
                    guard url.scheme == "steno", url.host == "transcribe" else { return }
                    let polish = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?
                        .first(where: { $0.name == "polish" })?
                        .value == "1"
                    transcriptionStore.processSharedFile(polish: polish)
                }
        }
    }
}
