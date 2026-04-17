import SwiftUI

@main
struct StenoApp: App {
    @StateObject private var transcriptionStore = TranscriptionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(transcriptionStore)
                .onOpenURL { url in
                    if url.scheme == "steno", url.host == "transcribe" {
                        transcriptionStore.processSharedFile()
                    }
                }
        }
    }
}
