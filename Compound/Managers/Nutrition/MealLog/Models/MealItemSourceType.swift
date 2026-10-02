//
//  MealItemSourceType.swift
//  Compound
//
//  Created by Andrew Coyle on 01/03/2026.
//

enum MealItemSourceType: String, DataSyncModelProtocol, CaseIterable, Sendable {

    var id: String { self.rawValue }

    case ingredient
    case recipe
    /// Macros typed straight into the logger, with no food or recipe behind them. Such an item
    /// carries its own nutrients and resolves to nothing in the library, so the daily breakdown
    /// skips it while the daily totals still count it.
    case quickAdd = "quick_add"

    /// A meal item written by a newer build can name a source type this one has never heard of.
    /// Falling back keeps the rest of the meal readable instead of failing the whole document.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MealItemSourceType(rawValue: raw) ?? .ingredient
    }
}
