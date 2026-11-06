import Foundation
import Security

/// Reads (or creates) the SQLCipher passphrase from the Keychain.
///
/// The Flutter version stored it with `flutter_secure_storage`:
/// - class: generic password
/// - service: "flutter_secure_storage_service" (the plugin's default account name)
/// - account: "qattah_database_key_v1"
/// - value: UTF-8 string (base64url of 32 random bytes), used as the SQLCipher passphrase
///
/// The Swift app uses the **same item**, so updating from the App Store keeps
/// every user's data readable.
struct DatabaseKeyStore {
    static let service = "flutter_secure_storage_service"
    static let account = "qattah_database_key_v1"

    /// Set to a shared keychain access group once the widget extension needs the key.
    var accessGroup: String?

    enum KeyError: LocalizedError {
        case keychain(OSStatus)

        var errorDescription: String? {
            switch self {
            case .keychain(let status):
                let message = SecCopyErrorMessageString(status, nil) as String? ?? "\(status)"
                return "تعذّر الوصول إلى سلسلة المفاتيح: \(message)"
            }
        }
    }

    func readKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeyError.keychain(status) }
        guard let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else { return nil }
        return key
    }

    /// Creates a new random passphrase in the same format the Flutter app used.
    func createKey() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw KeyError.keychain(status) }

        let key = Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")

        var query = baseQuery()
        query[kSecValueData as String] = Data(key.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeyError.keychain(addStatus) }
        return key
    }

    /// The Flutter app saved the key as "this device only", so it was NOT
    /// included in iCloud / encrypted backups while the database file was.
    /// Restoring onto a new iPhone therefore left an unreadable database.
    /// Switching to `AfterFirstUnlock` lets the key travel with encrypted
    /// backups (it is still never synced to iCloud Keychain).
    func makeKeyTransferableWithBackups() throws {
        let attributes: [String: Any] = [kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        let status = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyError.keychain(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}
