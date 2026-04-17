import Foundation

enum Config {
    static let apiBaseURL = "https://steno-836899141951.us-central1.run.app"
    static let transcribePath = "/transcribe"
    static let appGroupID = "group.com.parisyee.steno"
    static let sharedFileName = "shared_audio.m4a"

    // `apiKey` is declared in Shared/Secrets.swift (gitignored).
    // Copy Shared/Secrets.swift.example → Shared/Secrets.swift and fill in the real key.

    static var transcribeURL: URL {
        URL(string: apiBaseURL + transcribePath)!
    }

    static var sharedContainerURL: URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        )!
    }

    static var sharedFileURL: URL {
        sharedContainerURL.appendingPathComponent(sharedFileName)
    }
}
