//
//  KeyedDecodingContainer+EXT.swift
//  Compound
//

import Foundation

extension KeyedDecodingContainer {

    /// The value at `key`, or `fallback` when it is missing, null or unreadable.
    ///
    /// For settings documents, where one field written before it existed (or by an older build)
    /// must not cost the user every other field: Firestore's listener skips a document that fails
    /// to decode without a word, the screen shows defaults, and the next save overwrites the lot.
    func decode<T: Decodable>(_ key: Key, or fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }
}

/// A coding key for a name known only at run time, for reading keys a model does not declare.
struct AnyCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(_ stringValue: String) { self.stringValue = stringValue }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
