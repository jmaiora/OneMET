import Foundation
import Security

// GlucoseSourceStore.swift — persists the Nightscout config (URL + enabled in
// UserDefaults, secret in the Keychain).

enum Keychain {
    static func set(_ value: String, for key: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
    static func get(_ key: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrAccount as String: key,
                                     kSecReturnData as String: true,
                                     kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func delete(_ key: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrAccount as String: key] as CFDictionary)
    }
}

@MainActor
final class GlucoseSourceStore: ObservableObject {
    @Published var config: NightscoutConfig { didSet { persist() } }
    @Published var dexcom: DexcomConfig { didSet { persistDexcom() } }

    private let urlKey = "onemet.ns.url"
    private let enabledKey = "onemet.ns.enabled"
    private let tokenKey = "onemet.ns.token"

    private let dexUserKey = "onemet.dex.user"
    private let dexEnabledKey = "onemet.dex.enabled"
    private let dexOusKey = "onemet.dex.ous"
    private let dexPassKey = "onemet.dex.pass"

    init() {
        let url = UserDefaults.standard.string(forKey: urlKey) ?? ""
        let enabled = UserDefaults.standard.bool(forKey: enabledKey)
        let secret = Keychain.get(tokenKey) ?? ""
        config = NightscoutConfig(urlString: url, secret: secret, enabled: enabled)

        let dexUser = UserDefaults.standard.string(forKey: dexUserKey) ?? ""
        let dexEnabled = UserDefaults.standard.bool(forKey: dexEnabledKey)
        let dexOus = UserDefaults.standard.object(forKey: dexOusKey) as? Bool ?? true
        let dexPass = Keychain.get(dexPassKey) ?? ""
        dexcom = DexcomConfig(username: dexUser, password: dexPass, ous: dexOus, enabled: dexEnabled)
    }

    private func persist() {
        UserDefaults.standard.set(config.urlString, forKey: urlKey)
        UserDefaults.standard.set(config.enabled, forKey: enabledKey)
        if config.secret.isEmpty { Keychain.delete(tokenKey) }
        else { Keychain.set(config.secret, for: tokenKey) }
    }

    private func persistDexcom() {
        UserDefaults.standard.set(dexcom.username, forKey: dexUserKey)
        UserDefaults.standard.set(dexcom.enabled, forKey: dexEnabledKey)
        UserDefaults.standard.set(dexcom.ous, forKey: dexOusKey)
        if dexcom.password.isEmpty { Keychain.delete(dexPassKey) }
        else { Keychain.set(dexcom.password, for: dexPassKey) }
    }
}
