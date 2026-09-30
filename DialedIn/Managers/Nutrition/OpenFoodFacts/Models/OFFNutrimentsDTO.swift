//
//  OFFNutrimentsDTO.swift
//  DialedIn
//
//  Created by Andrew Coyle on 12/03/2026.
//

import Foundation

/// A product's `nutriments` object: every numeric `<name>_100g` field, keyed by `<name>`. OFF has
/// dozens of optional names (and spells several B vitamins two ways), so they are kept as a
/// dictionary and read through `OFFProductDTO.nutrientTable` rather than one property each.
struct OFFNutrimentsDTO: Decodable {
    let per100g: [String: Double]

    init(per100g: [String: Double]) {
        self.per100g = per100g
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        var values: [String: Double] = [:]
        for key in container.allKeys where key.stringValue.hasSuffix("_100g") {
            // Numbers only: a few products carry a string such as "" in a nutrient field.
            if let value = try? container.decode(Double.self, forKey: key), value.isFinite {
                values[String(key.stringValue.dropLast("_100g".count))] = value
            }
        }
        per100g = values
    }

    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}
