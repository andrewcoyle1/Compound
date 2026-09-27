//
//  MealItemRowStyle.swift
//  DialedIn
//

import SwiftUI

/// How a meal item row is drawn, as one value.
///
/// These options used to be five separate parameters threaded from `FoodLogSettings` through
/// `NutritionPresenter` and `NutritionView` into `MealItemRowView` one at a time, so adding a
/// sixth display option meant editing four files. Add it here instead and every row sees it.
struct MealItemRowStyle {

    /// Whether the row reserves its timestamp gutter at all.
    ///
    /// Deliberately separate from whether *this* row prints a time — see
    /// `MealItemRowView.timestamp`. Only a meal's first item prints one; the rest hold the space
    /// so the food names stay in a single column.
    var showsTimestampColumn: Bool = true

    var timestampSide: TimestampSide = .left
    var showsImage: Bool = true
    var showsCalories: Bool = true
    var showsMacros: Bool = true

    /// Zero when the column is off. Reserving the width regardless is what left the rows indented
    /// against nothing wherever timestamps were turned off.
    var timestampColumnWidth: CGFloat {
        showsTimestampColumn ? 80 : 0
    }

    /// The gutter's inset sits on the outer edge, so it does not close the gap between the time
    /// and the food name it belongs to.
    var timestampColumnEdge: Edge.Set {
        timestampSide == .left ? .leading : .trailing
    }

    var timestampAlignment: Alignment {
        timestampSide == .left ? .leading : .trailing
    }

    /// Meal detail lists the items of one meal, and its header already carries that meal's time,
    /// so a per-row timestamp would only repeat it.
    static let mealDetail = MealItemRowStyle(showsTimestampColumn: false)
}
