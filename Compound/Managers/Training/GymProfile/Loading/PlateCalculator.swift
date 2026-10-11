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
    /// The plate's colour as hex, from the gym, for drawing it; `nil` draws it plain.
    var colour: String?
}

enum PlateCalculator {

    enum Result: Equatable {
        /// Plates for one sleeve, heaviest first: each side of a bar, or everything on a
        /// single-post machine. Empty is the bare bar.
        case loadable(perSide: [Double])
        /// Not reachable with these plates; the closest totals that are, below and above.
        case notLoadable(below: Double?, above: Double?)
    }

    /// The plates for one sleeve, the same on each of `sleeves`: greedy from the heaviest when that
    /// works, as a lifter loads, otherwise any combination the gym's plates and counts allow.
    /// `total`, `bar` and `plates` share a unit.
    static func load(total: Double, bar: Double, plates: [Plate], sleeves: Int = 2) -> Result {
        let sleeves = max(sleeves, 1)
        let usable = plates.filter { $0.weight > 0 && ($0.perSleeve ?? 1) > 0 }
        let target = (total - bar) / Double(sleeves)
        if abs(target) < epsilon { return .loadable(perSide: []) }
        guard target > 0 else { return .notLoadable(below: nil, above: bar) }
        guard !usable.isEmpty else { return .notLoadable(below: nil, above: nil) }
        if let perSide = greedy(target, plates: usable) { return .loadable(perSide: perSide) }

        let sums = Sums(plates: usable, upTo: target + (usable.map(\.weight).max() ?? 0))
        let wanted = Int((target * scale).rounded())
        if abs(Double(wanted) - target * scale) < epsilon * scale, let perSide = sums.plates(making: wanted) {
            return .loadable(perSide: perSide)
        }
        let toTotal = { (side: Int) in ((bar + Double(side) / scale * Double(sleeves)) * 1000).rounded() / 1000 }
        let below = sums.reachable(atMost: Int((target * scale).rounded(.down))).map(toTotal)
        let above = sums.reachable(atLeast: Int((target * scale).rounded(.up))).map(toTotal)
        return .notLoadable(below: below, above: above)
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

    /// Heaviest first, as many of each as its cap allows; `nil` where that leaves a remainder.
    private static func greedy(_ target: Double, plates: [Plate]) -> [Double]? {
        var remaining = target
        var loaded: [Double] = []
        for plate in plates.sorted(by: { $0.weight > $1.weight }) {
            var used = 0
            while remaining + epsilon >= plate.weight, used < plate.perSleeve ?? .max {
                loaded.append(plate.weight)
                remaining -= plate.weight
                used += 1
            }
        }
        return abs(remaining) < epsilon ? loaded : nil
    }

    /// Every per-sleeve weight the plates can make up to a bound, in thousandths so plates labelled
    /// in the other unit (1.134 kg, 2.268 kg) add exactly. A bounded subset sum: each plate weight
    /// is used at most its `perSleeve` times, and each reachable sum remembers the plate that
    /// reached it first, heaviest plates first, so the breakdown can be read back.
    private struct Sums {
        private let weights: [Int]
        private var via: [Int]

        init(plates: [Plate], upTo limit: Double) {
            let sorted = plates.sorted { $0.weight > $1.weight }
            weights = sorted.map { Int(($0.weight * scale).rounded()) }
            // ponytail: one slot per gram up to a tonne a sleeve; plenty for any bar.
            let size = min(Int((limit * scale).rounded(.up)), 1_000_000) + 1
            via = Array(repeating: -1, count: size)
            via[0] = Int.max
            for (index, plate) in sorted.enumerated() {
                let weight = weights[index]
                guard weight > 0, weight < size else { continue }
                var used = Array(repeating: 0, count: size)
                for sum in weight..<size where via[sum] == -1 && via[sum - weight] != -1 && used[sum - weight] < (plate.perSleeve ?? .max) {
                    via[sum] = index
                    used[sum] = used[sum - weight] + 1
                }
            }
        }

        func plates(making sum: Int) -> [Double]? {
            guard sum >= 0, sum < via.count, via[sum] != -1 else { return nil }
            var sum = sum
            var loaded: [Double] = []
            while sum > 0 {
                let index = via[sum]
                loaded.append(Double(weights[index]) / scale)
                sum -= weights[index]
            }
            return loaded.sorted(by: >)
        }

        func reachable(atMost sum: Int) -> Int? {
            stride(from: min(sum, via.count - 1), through: 0, by: -1).first { via[$0] != -1 }
        }

        func reachable(atLeast sum: Int) -> Int? {
            guard sum < via.count else { return nil }
            return (max(sum, 0)..<via.count).first { via[$0] != -1 }
        }
    }

    private static let scale = 1000.0
    private static let epsilon = 0.001
}
