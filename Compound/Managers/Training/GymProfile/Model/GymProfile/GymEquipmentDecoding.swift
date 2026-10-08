//
//  GymEquipmentDecoding.swift
//  Compound
//
//  Helpers that let a stored gym profile decode when its equipment lists are incomplete or hold
//  an item this build cannot read. Firestore's listener skips a document that fails to decode
//  without a word, and the local cache drops every profile with it, so one bad item must never
//  cost the user the whole gym.
//

import Foundation

extension KeyedDecodingContainer {

    /// Decodes an array, skipping any element that fails to decode instead of failing the array.
    /// Returns nil when the key is absent, null or not an array, so the caller can fall back to a
    /// default.
    func decodeLossyArray<Element: Decodable>(_ type: Element.Type, forKey key: Key) -> [Element]? {
        guard var container = try? nestedUnkeyedContainer(forKey: key) else { return nil }
        var elements: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else if (try? container.decode(SkippedElement.self)) == nil {
                // A decoder that cannot even step past the element would loop forever here.
                break
            }
        }
        return elements
    }
}

/// Decodes any value without reading it, which moves an unkeyed container past an element that
/// failed to decode.
private struct SkippedElement: Decodable {
    init(from decoder: Decoder) throws { }
}

extension Array where Element: GymEquipmentItem {

    /// The stored list, followed by every catalogue item it lacks, switched off. This is how
    /// equipment added to the catalogue in a later release reaches gyms saved before it. Only the
    /// user's own and duplicated machines can be deleted, and their ids are ones the catalogue
    /// never had, so a catalogue id missing from the stored list was never there, and appending
    /// it brings back nothing the user removed. A missing list is the catalogue as is.
    static func mergingCatalogue(_ stored: [Element]?, _ catalogue: [Element]) -> [Element] {
        guard let stored else { return catalogue }
        let storedIds = Set(stored.map(\.id))
        let missing = catalogue
            .filter { !storedIds.contains($0.id) }
            .map { item in
                var item = item
                item.isActive = false
                return item
            }
        return stored + missing
    }
}
