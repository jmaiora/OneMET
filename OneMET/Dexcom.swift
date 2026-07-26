import Foundation

// Dexcom.swift — low-latency glucose from the Dexcom Share ("Follow") service.
// Read-only. Uses the well-known Share application id (as xDrip+/Nightscout do).
// Share only retains ~24 h of data, so it's for live/recent glucose, not long history.

struct DexcomConfig: Equatable {
    var username: String = ""      // Dexcom (Share) account: email, username or phone
    var password: String = ""
    var ous: Bool = true           // true = outside US (EU/rest); false = US
    var enabled: Bool = false

    var isConfigured: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }
    var isActive: Bool { enabled && isConfigured }
    var regionLabel: String { ous ? "Outside US" : "United States" }
}

enum DexcomError: Error { case auth, http(Int) }

struct DexcomShareClient {
    let config: DexcomConfig

    private static let appId = "d89443d2-327c-4a6f-89e5-496bbb0317db"
    private static let nullGUID = "00000000-0000-0000-0000-000000000000"

    private var base: String {
        config.ous ? "https://shareous1.dexcom.com/ShareWebServices/Services"
                   : "https://share2.dexcom.com/ShareWebServices/Services"
    }

    /// Fetch SGV entries in [from, to] as (date, mg/dL), ascending.
    func entries(from: Date, to: Date) async throws -> [(date: Date, v: Double)] {
        let sid = try await sessionId()
        let now = Date()
        let minutes = max(1, min(1440, Int((now.timeIntervalSince(from) / 60).rounded(.up))))
        let maxCount = max(1, min(288, minutes / 5 + 2))
        let data = try await post("/Publisher/ReadPublisherLatestGlucoseValues", query: [
            URLQueryItem(name: "sessionId", value: sid),
            URLQueryItem(name: "minutes", value: String(minutes)),
            URLQueryItem(name: "maxCount", value: String(maxCount)),
        ])
        let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
        return arr.compactMap { e -> (date: Date, v: Double)? in
            guard let value = (e["Value"] as? NSNumber)?.doubleValue,
                  let ms = Self.parseWT((e["WT"] as? String) ?? (e["ST"] as? String) ?? "") else { return nil }
            return (Date(timeIntervalSince1970: ms / 1000), value)
        }
        .filter { $0.date >= from && $0.date <= to }
        .sorted { $0.date < $1.date }
    }

    /// Connectivity check — try to fetch the last few hours of readings.
    func test() async -> Bool {
        let now = Date()
        let r = try? await entries(from: now.addingTimeInterval(-3 * 3600), to: now)
        return (r?.isEmpty == false)
    }

    // MARK: - Auth (account id → session id)

    private func sessionId() async throws -> String {
        let acct = try await post("/General/AuthenticatePublisherAccount", json: [
            "accountName": config.username, "password": config.password, "applicationId": Self.appId,
        ])
        let accountId = Self.unquote(acct)
        guard !accountId.isEmpty, accountId != Self.nullGUID else { throw DexcomError.auth }

        let sess = try await post("/General/LoginPublisherAccountById", json: [
            "accountId": accountId, "password": config.password, "applicationId": Self.appId,
        ])
        let sid = Self.unquote(sess)
        guard !sid.isEmpty, sid != Self.nullGUID else { throw DexcomError.auth }
        return sid
    }

    // MARK: - HTTP

    private func post(_ path: String, json: [String: Any]? = nil, query: [URLQueryItem] = []) async throws -> Data {
        guard var comps = URLComponents(string: base + path) else { throw DexcomError.http(-1) }
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { throw DexcomError.http(-1) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Dexcom Share/3.0.2.11 CFNetwork", forHTTPHeaderField: "User-Agent")
        if let json { req.httpBody = try JSONSerialization.data(withJSONObject: json) }
        req.timeoutInterval = 15
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw DexcomError.http(http.statusCode)
        }
        return data
    }

    private static func unquote(_ data: Data) -> String {
        (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"\n\r "))
    }

    /// Parse a WCF date like "/Date(1626902400000)/" or "/Date(1626902400000-0000)/" → epoch ms.
    private static func parseWT(_ s: String) -> Double? {
        guard let open = s.firstIndex(of: "(") else { return nil }
        var digits = ""
        for ch in s[s.index(after: open)...] {
            if ch.isNumber { digits.append(ch) } else { break }
        }
        return Double(digits)
    }
}
