//
//  NutrientMap.swift
//  Compound
//
//  Created by Andrew Coyle on 13/03/2026.
//

import Foundation

struct NutrientMap: Codable, Equatable, Hashable, Sendable, ExpressibleByDictionaryLiteral {
    private var storage: [NutrientKey: Double]

    init(_ dict: [NutrientKey: Double] = [:]) { storage = dict }

    init(dictionaryLiteral elements: (NutrientKey, Double)...) {
        storage = Dictionary(uniqueKeysWithValues: elements)
    }

    // MARK: Codable — encode/decode as [String: Double]

    /// Written out as a plain `[String: Double]`, minus anything that is not a usable number.
    ///
    /// A NaN already in memory must not be written back: `JSONEncoder` rejects one outright, so a
    /// single corrupt nutrient would fail the encode of the whole food or meal rather than of the
    /// one figure, and a remote store that accepts it hands the bad value straight back on the next
    /// read. Dropping here means a document written by this build is clean whatever it was built
    /// from.
    func encode(to encoder: Encoder) throws {
        let stringDict = Dictionary(uniqueKeysWithValues: storage.compactMap { entry in
            entry.value.isFinite ? (entry.key.rawValue, entry.value) : nil
        })
        try stringDict.encode(to: encoder)
    }

    /// The one gate every stored nutrient passes through, so it is the one place bad stored data
    /// can be turned away.
    ///
    /// Builds predating the input sanitising could persist a NaN or an infinity — an amount parsed
    /// from `"nan"` or an overflowing multiplication — and roughly fifteen screens print nutrients
    /// through `Int(_:)`, which traps rather than printing something odd, inside a view body. See
    /// `Double+EXT.swift` for the class.
    ///
    /// Such a value is **dropped rather than stored as zero**, for the same reason an unknown key
    /// is dropped: absent already means "this food's data does not record it", which is exactly
    /// what a corrupt figure amounts to, while zero would assert the food contains none of the
    /// nutrient. Breakdowns lean on that distinction — `recordedKeys(in:)` lists only what is
    /// really there, and `AddMealPresenter.breakdown(for:)` deliberately omits rather than prints
    /// `0 mcg`. The headline macros read through `?? 0`, so they are unaffected either way.
    init(from decoder: Decoder) throws {
        let stringDict = try [String: Double](from: decoder)
        storage = Dictionary(uniqueKeysWithValues: stringDict.compactMap {
            guard let key = NutrientKey(rawValue: $0.key), $0.value.isFinite else { return nil }
            return (key, $0.value)
        })
    }

    // MARK: Subscripts
    subscript(key: NutrientKey) -> Double? {
        get { storage[key] }
        set { storage[key] = newValue }
    }

    subscript(key: NutrientKey, default defaultValue: Double) -> Double {
        get { storage[key, default: defaultValue] }
        set { storage[key, default: defaultValue] = newValue }
    }

    // MARK: mapValues
    func mapValues(_ transform: (Double) throws -> Double) rethrows -> NutrientMap {
        NutrientMap(try storage.mapValues(transform))
    }

    /// Nutrients are stored per 100g/100ml, so logging an amount means scaling every value by the
    /// same factor. Callers pass `amount / 100`, not the amount itself.
    func scaled(by factor: Double) -> NutrientMap {
        mapValues { $0 * factor }
    }

    /// Sums two snapshots nutrient by nutrient, for totalling a plate or a day.
    ///
    /// A nutrient present in one map and absent from the other is carried through as-is: absent
    /// means "this food's data does not record it", not "this food contains none of it", but for a
    /// total there is nothing better to do than add what is known.
    static func + (lhs: NutrientMap, rhs: NutrientMap) -> NutrientMap {
        NutrientMap(lhs.storage.merging(rhs.storage) { $0 + $1 })
    }

    static func += (lhs: inout NutrientMap, rhs: NutrientMap) {
        lhs = lhs + rhs
    }

    /// The nutrients this map actually records, in `NutrientKey` declaration order so a breakdown
    /// reads total-first (total fat before saturated, carbs before fibre).
    func recordedKeys(in category: Macros) -> [NutrientKey] {
        category.details.filter { storage[$0] != nil }
    }
}

extension NutrientMap: Sequence {
    func makeIterator() -> Dictionary<NutrientKey, Double>.Iterator {
        storage.makeIterator()
    }
}
