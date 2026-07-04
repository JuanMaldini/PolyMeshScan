import Foundation

/// Cliente minimo de PocketBase: login + CRUD de scanner_scans.
/// Sin registro de usuarios (los crea el admin desde PocketBase).
@MainActor
final class PocketBase: ObservableObject {
    static let shared = PocketBase()

    @Published var token: String = UserDefaults.standard.string(forKey: "pb_token") ?? ""
    @Published var userId: String = UserDefaults.standard.string(forKey: "pb_userId") ?? ""
    @Published var baseURL: String = UserDefaults.standard.string(forKey: "pb_url") ?? ""

    var isLoggedIn: Bool { !token.isEmpty && !userId.isEmpty }

    struct AuthResponse: Decodable {
        let token: String
        let record: Record
        struct Record: Decodable { let id: String }
    }

    struct Scan: Decodable, Identifiable {
        let id: String
        let name: String
        let capture_mode: String
        let status: String
        let created: String
    }

    private struct ListResponse: Decodable { let items: [Scan] }

    enum PBError: LocalizedError {
        case badURL, http(Int, String)
        var errorDescription: String? {
            switch self {
            case .badURL: return "URL del servidor invalida"
            case .http(let code, let msg): return "HTTP \(code): \(msg)"
            }
        }
    }

    // MARK: - Auth

    func login(url: String, email: String, password: String) async throws {
        let clean = url.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let endpoint = URL(string: "\(clean)/api/collections/scanner_users/auth-with-password") else {
            throw PBError.badURL
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "identity": email, "password": password
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.check(resp, data)
        let auth = try JSONDecoder().decode(AuthResponse.self, from: data)
        token = auth.token
        userId = auth.record.id
        baseURL = clean
        UserDefaults.standard.set(token, forKey: "pb_token")
        UserDefaults.standard.set(userId, forKey: "pb_userId")
        UserDefaults.standard.set(clean, forKey: "pb_url")
    }

    func logout() {
        token = ""; userId = ""
        UserDefaults.standard.removeObject(forKey: "pb_token")
        UserDefaults.standard.removeObject(forKey: "pb_userId")
    }

    // MARK: - Scans

    func listScans() async throws -> [Scan] {
        var comps = URLComponents(string: "\(baseURL)/api/collections/scanner_scans/records")!
        comps.queryItems = [
            .init(name: "sort", value: "-created"),
            .init(name: "perPage", value: "100"),
            .init(name: "fields", value: "id,name,capture_mode,status,created"),
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.check(resp, data)
        return try JSONDecoder().decode(ListResponse.self, from: data).items
    }

    /// Crea un registro en scanner_scans con archivos (multipart).
    func createScan(
        name: String,
        captureMode: String,
        rawFile: URL,
        thumbnail: Data?,
        furnitureJSON: String?
    ) async throws {
        guard let endpoint = URL(string: "\(baseURL)/api/collections/scanner_scans/records") else {
            throw PBError.badURL
        }
        let boundary = "pms-\(UUID().uuidString)"
        var body = Data()

        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        func file(_ name: String, filename: String, mime: String, data: Data) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
            body.append("Content-Type: \(mime)\r\n\r\n")
            body.append(data)
            body.append("\r\n")
        }

        field("name", name)
        field("owner", userId)
        field("capture_mode", captureMode)
        field("status", "done") // sin pipeline todavia: queda done directo (ver docs/CAPTURE.md)
        if let furnitureJSON { field("furniture_json", furnitureJSON) }
        let raw = try Data(contentsOf: rawFile)
        file("raw_file", filename: rawFile.lastPathComponent,
             mime: "application/octet-stream", data: raw)
        if let thumbnail {
            file("thumbnail", filename: "thumb.jpg", mime: "image/jpeg", data: thumbnail)
        }
        body.append("--\(boundary)--\r\n")

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue(token, forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let (data, resp) = try await URLSession.shared.upload(for: req, from: body)
        try Self.check(resp, data)
    }

    private static func check(_ resp: URLResponse, _ data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw PBError.http(http.statusCode, String(msg.prefix(300)))
        }
    }
}

private extension Data {
    mutating func append(_ s: String) { append(s.data(using: .utf8)!) }
}
