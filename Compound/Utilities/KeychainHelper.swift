//
//  KeychainHelper.swift
//  Compound
//

import Foundation
import Security

struct KeychainHelper {

    /// Updates in place rather than delete-then-add, so a failed write leaves the old value rather
    /// than nothing. Readable after first unlock, so a workout finished from the Lock Screen can
    /// still reach the Strava tokens.
    static func save(_ value: String, forKey key: String, synchronizable: Bool = false) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            // Safe: kCFBooleanTrue/kCFBooleanFalse are CoreFoundation constants, never nil.
            kSecAttrSynchronizable: synchronizable ? kCFBooleanTrue! : kCFBooleanFalse!
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: Data(value.utf8),
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        guard SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound else { return }
        // A copy with the other synchronizable setting would shadow this one on read.
        var otherVariant = query
        // Safe: kCFBooleanTrue/kCFBooleanFalse are CoreFoundation constants, never nil.
        otherVariant[kSecAttrSynchronizable] = synchronizable ? kCFBooleanFalse! : kCFBooleanTrue!
        SecItemDelete(otherVariant as CFDictionary)
        SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
    }

    static func read(forKey key: String, synchronizable: Bool = false) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            // Safe: kCFBooleanTrue/kCFBooleanFalse are CoreFoundation constants, never nil.
            kSecAttrSynchronizable: synchronizable ? kCFBooleanTrue! : kCFBooleanFalse!
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String, synchronizable: Bool = false) {
        for sync in [true, false] {
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: key,
                // Safe: kCFBooleanTrue/kCFBooleanFalse are CoreFoundation constants, never nil.
                kSecAttrSynchronizable: sync ? kCFBooleanTrue! : kCFBooleanFalse!
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}
