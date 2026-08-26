import Foundation
import CryptoKit

// LibreLinkUp.swift — glucose from Abbott's LibreLinkUp ("follower") service, used by
// FreeStyle Libre 2 / 3 wearers who share with a follower account.
//
// Read-only, and unofficial: Abbott publishes no API, so this follows the same
// reverse-engineered protocol the community clients use. Two consequences worth knowing:
//   * the `version` header is checked, and Abbott bumps it — if logins start failing with
//     status 4, that constant is the first thing to raise;
//   * the graph endpoint only serves roughly the last 12 hours, so this is a live/recent
//     source, not a history one. `maxLookback` is what keeps the 14-day stats off it.
//
// You must log in with the *follower* account (the one that received the invite), not the
// account on the phone that reads the sensor.

struct LibreLinkUpConfig: Equatable {
    var email: String = ""
    var password: String = ""
    /// Abbott shards accounts by region; login tells us the right one and we remember it.
    var region: String = "eu"
    var enabled: Bool = false

    var isConfigured: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }
    var isActive: Bool { enabled && isConfigured }
}

enum LibreLinkUpError: Error {
    case auth
    case http(Int)
    case status(Int)          // Abbott's own status code in the JSON envelope
    case noConnection         // logged in, but no patient is sharing with this account
    case badResponse
}

struct LibreLinkUpClient {
    let config: LibreLinkUpConfig

    /// The graph endpoint returns ~12 h. Anything asking for more must go elsewhere.
    static let maxLookback: TimeInterval = 11.5 * 3600

    /// Regions Abbott shards on. `eu` is the usual default outside the Americas.
    static let regions = ["ae", "ap", "au", "ca", "de", "eu", "eu2", "fr", "jp", "la", "ru", "us"]

    /// Abbott validates this; bump it if logins start returning a non-zero status.
    private static let appVersion = "4.16.0"
    private static let product = "llu.android"

    private struct Session {
        let host: String
        let token: String
        let accountIdHash: String
    }

    private func host(_ region: String) -> String {
        "https://api-\(region).libreview.io"
    }

    // MARK: - Public

    /// Fetch glucose in [from, to] as (date, mg/dL), ascending.
    func entries(from: Date, to: Date) async throws -> [(date: Date, v: Double)] {
        let session = try await login()
        let patient = try await firstPatientId(session)
        let json = try await get("/llu/connections/\(patient)/graph", session: session)

        guard let data = json["data"] as? [String: Any] else { throw LibreLinkUpError.badResponse }

        var out: [(date: Date, v: Double)] = []
        for item in (data["graphData"] as? [[String: Any]] ?? []) {
            if let r = Self.reading(item) { out.append(r) }
        }
        // The connection carries the newest reading, which the graph array lags behind.
        if let conn = data["connection"] as? [String: Any],
           let latest = conn["glucoseMeasurement"] as? [String: Any],
           let r = Self.reading(latest) {
            out.append(r)
        }

        return out
            .filter { $0.date >= from && $0.date <= to }
            .sorted { $0.date < $1.date }
    }

    /// Connectivity check — log in and confirm a sharing patient with recent data.
    func test() async -> Bool {
        let now = Date()
        let r = try? await entries(from: now.addingTimeInterval(-3 * 3600), to: now)
        return (r?.isEmpty == false)
    }

    /// The region the account actually lives in, discovered at login. Returns nil if the
    /// credentials don't work at all.
    func detectRegion() async -> String? {
        (try? await login())?.host
            .replacingOccurrences(of: "https://api-", with: "")
            .replacingOccurrences(of: ".libreview.io", with: "")
    }

    // MARK: - Auth

    private func login() async throws -> Session {
        var region = config.region
        // One redirect hop: Abbott answers a login on the wrong shard with the right one.
        for attempt in 0..<2 {
            let body = try JSONSerialization.data(withJSONObject: [
                "email": config.email, "password": config.password,
            ])
            let json = try await request("POST", host(region) + "/llu/auth/login",
                                         body: body, session: nil)

            if let status = json["status"] as? Int, status != 0 {
                throw LibreLinkUpError.status(status)
            }
            guard let data = json["data"] as? [String: Any] else { throw LibreLinkUpError.badResponse }

            if attempt == 0, (data["redirect"] as? Bool) == true,
               let r = data["region"] as? String, !r.isEmpty {
                region = r
                continue
            }
            guard let ticket = data["authTicket"] as? [String: Any],
                  let token = ticket["token"] as? String, !token.isEmpty,
                  let user = data["user"] as? [String: Any],
                  let userId = user["id"] as? String
            else { throw LibreLinkUpError.auth }

            return Session(host: host(region), token: token,
                           accountIdHash: Self.sha256Hex(userId))
        }
        throw LibreLinkUpError.auth
    }

    private func firstPatientId(_ session: Session) async throws -> String {
        let json = try await get("/llu/connections", session: session)
        guard let list = json["data"] as? [[String: Any]] else { throw LibreLinkUpError.badResponse }
        guard let id = list.compactMap({ $0["patientId"] as? String }).first else {
            throw LibreLinkUpError.noConnection
        }
        return id
    }

    // MARK: - HTTP

    private func get(_ path: String, session: Session) async throws -> [String: Any] {
        try await request("GET", session.host + path, body: nil, session: session)
    }

    private func request(_ method: String, _ urlString: String,
                         body: Data?, session: Session?) async throws -> [String: Any] {
        guard let url = URL(string: urlString) else { throw LibreLinkUpError.http(-1) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(Self.product, forHTTPHeaderField: "product")
        req.setValue(Self.appVersion, forHTTPHeaderField: "version")
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        if let session {
            req.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
            // Required on authenticated calls since the 4.12 protocol change.
            req.setValue(session.accountIdHash, forHTTPHeaderField: "Account-Id")
        }
        req.httpBody = body
        req.timeoutInterval = 15

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw LibreLinkUpError.http(http.statusCode)
        }
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw LibreLinkUpError.badResponse
        }
        return json
    }

    // MARK: - Parsing

    /// Abbott sends US-format timestamps as strings. FactoryTimestamp is UTC; Timestamp is
    /// the sharer's local wall clock, which we can't resolve, so UTC is the one to trust.
    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "M/d/yyyy h:mm:ss a"
        return f
    }()

    private static func reading(_ item: [String: Any]) -> (date: Date, v: Double)? {
        guard let mgdl = (item["ValueInMgPerDl"] as? NSNumber)?.doubleValue, mgdl > 0,
              let ts = item["FactoryTimestamp"] as? String,
              let date = stamp.date(from: ts)
        else { return nil }
        return (date, mgdl)
    }

    private static func sha256Hex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
