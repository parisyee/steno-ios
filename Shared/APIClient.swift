import Foundation

enum APIError: LocalizedError {
    case badStatus(Int, String?)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code, let body):
            if let body, !body.isEmpty { return "Server \(code): \(body)" }
            return "Server returned \(code)"
        case .decoding(let msg): return "Couldn't parse response: \(msg)"
        case .transport(let msg): return msg
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)

        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = Self.iso8601WithFractional.date(from: raw) { return date }
            if let date = Self.iso8601Plain.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date: \(raw)"
            )
        }
        self.decoder = d
    }

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - List

    struct ListResponse: Decodable {
        let transcriptions: [Transcription]
    }

    func list(limit: Int = 20, offset: Int = 0) async throws -> [Transcription] {
        var comps = URLComponents(string: Config.apiBaseURL + "/transcriptions")!
        comps.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        let request = authed(URLRequest(url: comps.url!))
        let data = try await send(request)
        do {
            return try decoder.decode(ListResponse.self, from: data).transcriptions
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    // MARK: - Delete

    func delete(id: UUID) async throws {
        let url = URL(string: Config.apiBaseURL + "/transcriptions/\(id.uuidString.lowercased())")!
        var request = authed(URLRequest(url: url))
        request.httpMethod = "DELETE"
        _ = try await send(request, expectStatus: 204)
    }

    // MARK: - Transcribe

    func transcribe(
        audioData: Data,
        filename: String = "audio.m4a",
        polish: Bool = false
    ) async throws -> Transcription {
        var comps = URLComponents(url: Config.transcribeURL, resolvingAgainstBaseURL: false)!
        if polish {
            comps.queryItems = [URLQueryItem(name: "polish", value: "true")]
        }
        var request = authed(URLRequest(url: comps.url!))
        request.httpMethod = "POST"
        request.timeoutInterval = 600

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: audio/mp4\r\n\r\n")
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let data = try await send(request)
        do {
            return try decoder.decode(Transcription.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    // MARK: - Internals

    private func authed(_ request: URLRequest) -> URLRequest {
        var r = request
        r.setValue("Bearer \(Config.apiKey)", forHTTPHeaderField: "Authorization")
        return r
    }

    @discardableResult
    private func send(_ request: URLRequest, expectStatus: Int? = nil) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Not an HTTP response")
        }
        if let expectStatus, http.statusCode == expectStatus { return data }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw APIError.badStatus(http.statusCode, body)
        }
        return data
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }
}
