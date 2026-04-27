import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let titleLabel = UILabel()
    private let polishLabel = UILabel()
    private let polishSublabel = UILabel()
    private let polishSwitch = UISwitch()
    private let uploadButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let activity = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildUI()
    }

    // MARK: - UI

    private func buildUI() {
        titleLabel.text = "Upload to Steno"
        titleLabel.font = .preferredFont(forTextStyle: .title2).withSymbolicTraits(.traitBold)
        titleLabel.textAlignment = .center

        polishLabel.text = "Generate polished version"
        polishLabel.font = .preferredFont(forTextStyle: .body)

        polishSublabel.text = "Cleans up disfluencies and smooths stutters. Uses more tokens."
        polishSublabel.font = .preferredFont(forTextStyle: .footnote)
        polishSublabel.textColor = .secondaryLabel
        polishSublabel.numberOfLines = 0

        polishSwitch.isOn = false

        var uploadConfig = UIButton.Configuration.filled()
        uploadConfig.title = "Upload"
        uploadConfig.buttonSize = .large
        uploadConfig.cornerStyle = .medium
        uploadButton.configuration = uploadConfig
        uploadButton.addTarget(self, action: #selector(didTapUpload), for: .touchUpInside)

        var cancelConfig = UIButton.Configuration.plain()
        cancelConfig.title = "Cancel"
        cancelConfig.buttonSize = .large
        cancelButton.configuration = cancelConfig
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)

        let polishRow = UIStackView(arrangedSubviews: [polishLabel, polishSwitch])
        polishRow.axis = .horizontal
        polishRow.alignment = .center
        polishRow.spacing = 12

        let polishBlock = UIStackView(arrangedSubviews: [polishRow, polishSublabel])
        polishBlock.axis = .vertical
        polishBlock.spacing = 6

        let buttonStack = UIStackView(arrangedSubviews: [uploadButton, cancelButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 4

        let root = UIStackView(arrangedSubviews: [titleLabel, polishBlock, buttonStack])
        root.axis = .vertical
        root.spacing = 24
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.hidesWhenStopped = true
        view.addSubview(activity)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            root.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            activity.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func didTapCancel() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    @objc private func didTapUpload() {
        setBusy(true)
        let polish = polishSwitch.isOn

        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = item.attachments?.first,
              attachment.hasItemConformingToTypeIdentifier(UTType.audio.identifier) else {
            complete()
            return
        }

        attachment.loadFileRepresentation(forTypeIdentifier: UTType.audio.identifier) { [weak self] url, error in
            guard let self else { return }

            guard let url else {
                DispatchQueue.main.async { self.showError(error?.localizedDescription ?? "Could not load audio file.") }
                return
            }

            // Server caps uploads at 2 GB (Gemini File API limit); reject
            // earlier so the user gets a friendly error instead of a 413
            // mid-upload.
            let maxBytes: Int64 = 2 * 1024 * 1024 * 1024
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64, size > maxBytes {
                DispatchQueue.main.async {
                    self.showError("File is too large. Maximum supported size is 2 GB.")
                }
                return
            }

            let destURL = Config.sharedFileURL
            try? FileManager.default.removeItem(at: destURL)
            do {
                try FileManager.default.copyItem(at: url, to: destURL)
                DispatchQueue.main.async {
                    self.openMainApp(polish: polish)
                    self.complete()
                }
            } catch {
                DispatchQueue.main.async { self.showError("Failed to save audio file: \(error.localizedDescription)") }
            }
        }
    }

    private func setBusy(_ busy: Bool) {
        uploadButton.isEnabled = !busy
        cancelButton.isEnabled = !busy
        polishSwitch.isEnabled = !busy
        if busy { activity.startAnimating() } else { activity.stopAnimating() }
    }

    private func openMainApp(polish: Bool) {
        var comps = URLComponents()
        comps.scheme = "steno"
        comps.host = "transcribe"
        if polish {
            comps.queryItems = [URLQueryItem(name: "polish", value: "1")]
        }
        guard let url = comps.url else { return }

        var responder: UIResponder? = self
        while let r = responder {
            if let application = r as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = r.next
        }
        extensionContext?.open(url, completionHandler: nil)
    }

    private func showError(_ message: String) {
        setBusy(false)
        let alert = UIAlertController(title: "Upload Failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.complete()
        })
        present(alert, animated: true)
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

private extension UIFont {
    func withSymbolicTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
