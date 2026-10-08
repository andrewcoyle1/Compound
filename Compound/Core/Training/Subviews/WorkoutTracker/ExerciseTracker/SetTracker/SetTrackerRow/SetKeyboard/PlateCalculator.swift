//
//  PlateCalculator.swift
//  Compound
//
//  Which plates go on each side of a bar for a given total. Pure.
//

import Foundation

enum PlateCalculator {

    enum Result: Equatable {
        /// Plates for one side, heaviest first. Empty is the bare bar.
        case loadable(perSide: [Double])
        /// Not reachable with these plates; the closest totals that are, below and above.
        case notLoadable(below: Double?, above: Double?)
    }

    /// Greedy from the heaviest plate, any number of each. `total`, `bar` and `plates` share a unit.
    static func load(total: Double, bar: Double, plates: [Double]) -> Result {
        if let perSide = perSide(total: total, bar: bar, plates: plates) {
            return .loadable(perSide: perSide)
        }
        return .notLoadable(below: nearest(to: total, bar: bar, plates: plates, upward: false),
                            above: nearest(to: total, bar: bar, plates: plates, upward: true))
    }

    /// `total` if the bar can carry it, otherwise the closer of the loadable totals either side, the
    /// lighter on a tie. A total nothing can reach is returned as it was.
    static func nearestLoadable(total: Double, bar: Double, plates: [Double]) -> Double {
        switch load(total: total, bar: bar, plates: plates) {
        case .loadable:
            return total
        case let .notLoadable(below?, above?):
            return above - total < total - below ? above : below
        case let .notLoadable(below, above):
            return below ?? above ?? total
        }
    }

    /// `weightKg` as the nearest total a bar with these plates can carry, in kilograms. The plates
    /// are labelled in `unit`, so the match is made there and converted back.
    static func nearestLoadableKg(_ weightKg: Double, bar: Double, plates: [Double], unit: ExerciseWeightUnit) -> Double {
        let total = (UnitConversion.convertWeight(weightKg, to: unit) * 1000).rounded() / 1000
        return UnitConversion.convertWeightToKg(nearestLoadable(total: total, bar: bar, plates: plates), from: unit)
    }

    private static func perSide(total: Double, bar: Double, plates: [Double]) -> [Double]? {
        var remaining = (total - bar) / 2
        guard remaining > -epsilon else { return nil }
        var loaded: [Double] = []
        for plate in plates.filter({ $0 > 0 }).sorted(by: >) {
            while remaining + epsilon >= plate {
                loaded.append(plate)
                remaining -= plate
            }
        }
        return abs(remaining) < epsilon ? loaded : nil
    }

    /// The closest loadable total on one side of `total`, scanning per-side weights on a
    /// quarter-unit grid.
    private static func nearest(to total: Double, bar: Double, plates: [Double], upward: Bool) -> Double? {
        // ponytail: grid scan of greedy loads, bounded to two of the heaviest plates a side; a
        // subset-sum search if odd plate sets (no small plates) ever need an exact answer.
        guard let heaviest = plates.max() else { return nil }
        if total < bar { return upward ? bar : nil }
        let start = ((total - bar) / 2 / grid).rounded(upward ? .up : .down) * grid
        let limit = Int(heaviest * 2 / grid)
        for offset in 0...limit {
            let side = start + Double(offset) * grid * (upward ? 1 : -1)
            guard side >= 0 else { return bar }
            let candidate = bar + side * 2
            guard abs(candidate - total) > epsilon else { continue }
            if perSide(total: candidate, bar: bar, plates: plates) != nil { return candidate }
        }
        return nil
    }

    private static let grid = 0.25
    private static let epsilon = 0.001
}
