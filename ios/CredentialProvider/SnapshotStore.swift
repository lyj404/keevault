import Foundation

/// Reads + decrypts the KeeVault autofill snapshot written by the main app
/// to the shared App Group container. The AES-256-GCM key lives in the shared
/// Keychain (same access group the app wrote it with via flutter_secure_storage).
///
/// File layout (see Dart `AutofillSnapshotFile`):
///   bytes 0..3  : "KVAF"
///   byte  4     : format version (1)
///   bytes 5..   : AES-GCM combined = nonce(12) || ciphertext || tag(16)
final class SnapshotStore {
    static let appGroupId = "group.com.keevault.keevault"
    static let fileName = "keevault_autofill_snapshot.bin"
    static let keychainAccount = "autofill_snapshot_key"

    struct Entry {
        let uuid: String
        let title: String
        let username: String
        let password: String
        let domains: [String]
        let packageIds: [String]
    }

    struct Snapshot {
        let createdAt: Int64
        let entries: [Entry]
    }

    /// Loads and decrypts the snapshot, or nil if missing/unreadable.
    static func load() -> Snapshot? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId
        ) else {
            return nil
        }
        let fileURL = containerURL.appendingPathComponent(fileName)
        guard let wrapped = try? Data(contentsOf: fileURL) else { return nil }
        guard wrapped.count >= 5 + 12 + 16 else { return nil }
        let magic: [UInt8] = [0x4B, 0x56, 0x41, 0x46] // "KVAF"
        for i in 0..<4 where wrapped[i] != magic[i] { return nil }
        guard wrapped[4] == 1 else { return nil }
        let combined = wrapped.subdata(in: 5..<wrapped.count)

        guard let key = readKey() else { return nil }
        do {
            let sealed = try AES.GCM.SealedBox(combined: combined)
            let plain = try AES.GCM.open(sealed, using: key)
            return parseSnapshot(plain)
        } catch {
            return nil
        }
    }

    /// Removes the snapshot file (best-effort), e.g. when the extension finds
    /// it cannot serve — the main app deletes it on lock, this is a fallback.
    static func clear() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId
        ) else { return }
        let fileURL = containerURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Keychain (mirrors flutter_secure_storage with IOSOptions(groupId:))

    private static func readKey() -> SymmetricKey? {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: keychainAccount,
            kSecAttrAccessGroup: appGroupId,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        // flutter_secure_storage tries synchronizable false first, then true.
        query[kSecAttrSynchronizable] = false
        if let data = copyMatching(query) { return toKey(data) }
        query[kSecAttrSynchronizable] = true
        if let data = copyMatching(query) { return toKey(data) }
        return nil
    }

    private static func copyMatching(_ query: [CFString: Any]) -> Data? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }

    private static func toKey(_ data: Data) -> SymmetricKey? {
        guard let s = String(data: data, encoding: .utf8),
              let raw = Data(base64Encoded: s),
              raw.count == 32
        else { return nil }
        return SymmetricKey(data: raw)
    }

    // MARK: - JSON parsing

    private static func parseSnapshot(_ data: Data) -> Snapshot? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entriesArr = json["entries"] as? [[String: Any]]
        else { return nil }
        let createdAt = (json["createdAt"] as? NSNumber)?.int64Value ?? 0
        var entries: [Entry] = []
        for e in entriesArr {
            let domains = (e["domains"] as? [String]) ?? []
            let packageIds = (e["packageIds"] as? [String]) ?? []
            entries.append(Entry(
                uuid: (e["uuid"] as? String) ?? "",
                title: (e["title"] as? String) ?? "",
                username: (e["username"] as? String) ?? "",
                password: (e["password"] as? String) ?? "",
                domains: domains,
                packageIds: packageIds
            ))
        }
        return Snapshot(createdAt: createdAt, entries: entries)
    }
}
