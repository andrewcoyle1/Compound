//
//  NutritionTypes.swift
//  Compound
//
//  Shared nutrition models used by ingredient templates.
//

import Foundation

// MARK: - Measurement Method

enum MeasurementMethod: String, Codable, CaseIterable, Sendable {
    case weight // e.g., grams
    case volume // e.g., milliliters, cups
}
