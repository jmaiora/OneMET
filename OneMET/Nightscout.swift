import Foundation
import CryptoKit

// Nightscout.swift — low-latency glucose source via the Nightscout REST API.
// Reads only (SGV entries). Config lives in GlucoseSourceStore (token in Keychain).

struct NightscoutConfig: Equatable {
    var urlString: String = ""
    var secret: String = ""      // access token ("role-token") or API secret passphrase
    var enabled: Bool = false

    var normalizedBase: String {
        var s = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty, !s.lowercased().hasPrefix("http") { s = "https://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }
    var isConfigured: Bool { !normalizedBase.isEmpty }
    var isActive: Bool { enabled && isConfigured }
}

enum NightscoutError: Error { case badURL, http(Int), decode }

struct NightscoutClient {
    let config: NightscoutConfig

    /// Fetch SGV entries in [from, to] as (date, mg/dL), ascending.
    func entries(from: Date, to: Date) async throws -> [(date: Date, v: Double)] {
        let fromMs = Int(from.timeIntervalSince1970 * 1000)
        let toMs = Int(to.timeIntervalSince1970 * 1000)
        guard var comps = URLComponents(string: config.normalizedBase + "/api/v1/entries/sgv.json") else {
            throw NightscoutError.badURL
        }
        // Pre-encoded so the Nightscout find[...] brackets survive URL building.
        var items = [
            URLQueryItem(name: "find%5Bdate%5D%5B$gte%5D", value: String(fromMs)),
            URLQueryItem(name: "find%5Bdate%5D%5B$lte%5D", value: String(toMs)),
            URLQueryItem(name: "count", value: "20000")
        ]
        let secret = config.secret.trimmingCharacters(in: .whitespacesAndNewlines)
        let useToken = secret.contains("-")     // role tokens look like "name-abc123…"
        if useToken, !secret.isEmpty {
            let enc = secret.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? secret
            items.append(URLQueryItem(name: "token", value: enc))
        }
        comps.percentEncodedQueryItems = items
        guard let url = comps.url else { throw NightscoutError.badURL }

        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if !useToken, !secret.isEmpty {
            req.setValue(Self.sha1Hex(secret), forHTTPHeaderField: "api-secret")
        }
        req.timeoutInterval = 15

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NightscoutError.http(http.statusCode)
        }
        let decoded = try JSONDecoder().decode([Entry].self, from: data)
        return decoded.compactMap { e -> (date: Date, v: Double)? in
            guard let sgv = e.sgv, let ms = e.date else { return nil }
            return (Date(timeIntervalSince1970: ms / 1000), sgv)
        }
        .sorted { $0.date < $1.date }
    }

    /// Lightweight connectivity check — fetch the last reading.
    func test() async -> Bool {
        let now = Date()
        let readings = try? await entries(from: now.addingTimeInterval(-6 * 3600), to: now)
        return (readings?.isEmpty == false)
    }

    private struct Entry: Decodable {
        let sgv: Double?
        let date: Double?
    }

    private static func sha1Hex(_ s: String) -> String {
        Insecure.SHA1.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
