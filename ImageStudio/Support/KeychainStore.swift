import Foundation
import Security

/// API Key 存 Keychain（机密不进 UserDefaults 明文）。
enum KeychainStore {
    private static let service = "app.image-studio.ImageStudio"
    private static let account = "relay-api-key"

    static func loadRelayKey() -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8)
        else { return "" }
        return key
    }

    static func saveRelayKey(_ key: String) {
        let base: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard !key.isEmpty, let data = key.data(using: .utf8) else { return }
        var add = base
        add[kSecValueData] = data
        SecItemAdd(add as CFDictionary, nil)
    }
}
