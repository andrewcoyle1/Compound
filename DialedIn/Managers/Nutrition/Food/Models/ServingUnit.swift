//
//  ServingUnit.swift
//  DialedIn
//
//  Created by Andrew Coyle on 25/09/2026.
//

import Foundation

/// A named household unit a food can be logged in — a slice, a cup, a piece — and how much of the
/// food's base unit one of it is. `grams` is millilitres for a food measured by volume.
struct ServingUnit: Codable, Hashable, Sendable {
    let name: String
    let grams: Double
}

extension FoodModel {

    /// The units this food can be logged in besides grams or millilitres, read from the portion
    /// it already declares. A portion is "`total` for `count` of `name`", e.g. 40g for half a cup,
    /// so one unit is `total / count`.
    ///
    /// Only portions in the food's own base unit are offered: a weighed food's volume portion has
    /// no gram figure to convert through. A portion named "g" or "ml" is the base unit again and
    /// is skipped.
    var servingUnits: [ServingUnit] {
        let portions: [ServingUnit?] = switch measurementMethod {
        case .weight: [Self.unit(portionName, servingWeight, portionSize), Self.unit(weightPortionName, portionWeight, weightPortionSize)]
        case .volume: [Self.unit(volumePortionName, portionVolume, volumePortionSize)]
        }
        return portions.compactMap { $0 }.reduce(into: []) { units, unit in
            if !units.contains(where: { $0.name == unit.name }) { units.append(unit) }
        }
    }

    private static func unit(_ name: String?, _ total: Double?, _ count: Double?) -> ServingUnit? {
        guard let name = name?.trimmingCharacters(in: .whitespaces), !name.isEmpty,
              !["g", "ml"].contains(name.lowercased()),
              let total, total.isFinite, total > 0 else { return nil }
        let count = count.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? 1
        return ServingUnit(name: name, grams: total / count)
    }
}
