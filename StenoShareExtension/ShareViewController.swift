import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = item.attachments?.first else {
            complete()
            return
        }

        let audioType = UTType.audio.identifier

        if attachment.hasItemConformingToTypeIdentifier(audioType) {
            attachment.loadItem(forTypeIdentifier: audioType, options: nil) { [weak self] data, error in
                guard let self = self else { return }

                var fileURL: URL?

                if let url = data as? URL {
                    fileURL = url
                } else if let data = data as? Data {
                    // Write data to temp file first
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio.m4a")
                    try? data.write(to: tempURL)
                    fileURL = tempURL
                }

                if let sourceURL = fileURL {
                    // Copy to shared App Group container
                    let destURL = Config.sharedFileURL
                    try? FileManager.default.removeItem(at: destURL)
                    try? FileManager.default.copyItem(at: sourceURL, to: destURL)

                    // Open main app to process the file
                    self.openMainApp()
                }

                self.complete()
            }
        } else {
            complete()
        }
    }

    override func configurationItems() -> [Any]! {
        return []
    }

    private func openMainApp() {
        // Open the main app via URL scheme
        let url = URL(string: "steno://transcribe")!
        var responder: UIResponder? = self

        while let r = responder {
            if let application = r as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = r.next
        }

        // Fallback: use the openURL selector
        extensionContext?.open(url, completionHandler: nil)
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
