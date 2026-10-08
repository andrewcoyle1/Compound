//
//  PlateCalculator.swift
//  Compound
//
//  Which plates go on each sleeve of a bar or machine for a given total. Pure.
//

import Foundation

/// One weight of plate a gym has.
struct Plate: Equatable {
    let weight: Double
    /// How many fit on one sleeve: the gym's count shared evenly between the sleeves, rounded
    /// down. `nil` is as many as a load needs.
    var perSleeve: Int?
}

enum PlateCalculator {

    enum Result: Equatable {
        /// Plates for one sleeve, heaviest first: each side of a bar, or everything on a
        /// single-post machine. Empty is the bare bar.
        case loadable(perSide: [Double])
        /// Not reachable with these plates; the closest totals that are, below and above.
        case notLoadable(below: Double?, above: Double?)
    }

    /// Greedy from the heaviest plate, as many of each as its `perSleeve` allows, the same on each
    /// of `sleeves`. `total`, `bar` and `plates` share a unit.
    static func load(total: Double, bar: Double, plates: [Plate], sleeves: Int = 2) -> Result {
        if let perSide = perSleeve(total: total, bar: bar, plates: plates, sleeves: sleeves) {
            return .loadable(perSide: perSide)
        }
        return .notLoadable(below: nearest(to: total, bar: bar, plates: plates, sleeves: sleeves, upward: false),
                            above: nearest(to: total, bar: bar, plates: plates, sleeves: sleeves, upward: true))
    }

    /// `total` if the bar can carry it, otherwise the closer of the loadable totals either side, the
    /// lighter on a tie. A total nothing can reach is returned as it was.
    static func nearestLoadable(total: Double, bar: Double, plates: [Plate], sleeves: Int = 2) -> Double {
        switch load(total: total, bar: bar, plates: plates, sleeves: sleeves) {
        case .loadable:
            return total
        case let .notLoadable(below?, above?):
            return above - total < total - below ? above : below
        case let .notLoadable(below, above):
            return below ?? above ?? total
        }
    }

    private static func perSleeve(total: Double, bar: Double, plates: [Plate], sleeves: Int) -> [Double]? {
        var remaining = (total - bar) / Double(max(sleeves, 1))
        guard remaining > -epsilon else { return nil }
        var loaded: [Double] = []
        for plate in plates.filter({ $0.weight > 0 }).sorted(by: { $0.weight > $1.weight }) {
            var used = 0
            while remaining + epsilon >= plate.weight, used < plate.perSleeve ?? .max {
                loaded.append(plate.weight)
                remaining -= plate.weight
                used += 1
            }
        }
        return abs(remaining) < epsilon ? loaded : nil
    }

    /// The closest loadable total on one side of `total`, scanning per-sleeve weights on a
    /// quarter-unit grid.
    private static func nearest(to total: Double, bar: Double, plates: [Plate], sleeves: Int, upward: Bool) -> Double? {
        // ponytail: grid scan of greedy loads, bounded to two of the heaviest plates a sleeve; a
        // subset-sum search if odd plate sets (no small plates) ever need an exact answer. Greedy
        // also misses loads that limited counts allow (one 25 a sleeve: 25 + 20 leaves 5 of 50,
        // where 20 + 15 + 15 makes it), which the same search would find.
        guard let heaviest = plates.map(\.weight).max() else { return nil }
        if total < bar { return upward ? bar : nil }
        let sleeves = Double(max(sleeves, 1))
        let start = ((total - bar) / sleeves / grid).rounded(upward ? .up : .down) * grid
        let limit = Int(heaviest * 2 / grid)
        for offset in 0...limit {
            let side = start + Double(offset) * grid * (upward ? 1 : -1)
            guard side >= 0 else { return bar }
            let candidate = bar + side * sleeves
            guard abs(candidate - total) > epsilon else { continue }
            if perSleeve(total: candidate, bar: bar, plates: plates, sleeves: Int(sleeves)) != nil { return candidate }
        }
        return nil
    }

    private static let grid = 0.25
    private static let epsilon = 0.001
}
