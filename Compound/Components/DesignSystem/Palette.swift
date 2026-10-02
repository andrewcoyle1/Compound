//
//  Palette.swift
//  Compound
//

import SwiftUI

// MARK: - Accent
//
// The accent is the brand colour. Today it is monochrome: the `AccentColor` asset is `labelColor`,
// and the `OnAccent` asset (text and glyphs drawn on an accent fill) is its inverse.
//
// **Change `AccentColor` and `OnAccent` together.** That one edit to two assets must recolour the
// whole app, which only holds if code never bypasses them:
//
// - Draw accent with `.tint` as a `ShapeStyle` (`.foregroundStyle(.tint)`, `.fill(.tint)`). Use
//   `Color.accentColor` only where a `Color` value is required. `Color.accent` / bare `.accent`
//   are retired.
// - Text on an accent fill uses `.onAccent` (generated from the asset), never `.white`, `.black`
//   or `colorScheme.*`.
// - Use the accent for primary buttons, selected state, non-data toggles/sliders/progress, links,
//   the active tab, focus rings and the user's own goal progress. Never for data meaning, body
//   text or surfaces, and never write its current value (`.primary`, `.black`, `labelColor`)
//   where the accent is meant.

// MARK: - Surfaces, data and status

/// Named colours. Nothing outside `DesignSystem/` writes `Color(red:…)`; the exceptions are user
/// data (`Color(hex:)`), share cards and the widget.
///
/// - `canvas` is the screen background, `surface` a card or grouped row on it.
/// - `tintedSurface(_:)` is the one fill for tinted tiles, chips and badges.
/// - Macro and nutrient colours are data: use them for that nutrient only.
/// - Errors are always `danger`, toasts included.
extension Color {
    /// A card or grouped row. Identical to the old `colorScheme.backgroundPrimary`.
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    /// The screen background behind surfaces. Identical to the old `colorScheme.backgroundSecondary`.
    static let canvas = Color(uiColor: .systemGroupedBackground)

    /// The fill for tinted tiles, chips and badges.
    static func tintedSurface(_ color: Color) -> Color { color.opacity(0.15) }

    // Macros and nutrient categories
    static let calories = Color.blue
    static let protein = Color(red: 0.9, green: 0.4, blue: 0.3)
    static let carbs = Color(red: 0.4, green: 0.75, blue: 0.5)
    static let fat = Color(red: 0.95, green: 0.75, blue: 0.2)
    static let vitamins = Color(red: 0.55, green: 0.35, blue: 0.75)
    static let minerals = Color(red: 0.95, green: 0.5, blue: 0.65)
    static let otherNutrients = Color(red: 0.55, green: 0.78, blue: 0.95)

    // Status. Never colour alone: pair it with a symbol or text.
    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red

    // Workout set kinds and records
    static let warmup = Color.orange
    static let superset = Color.indigo
    static let personalRecord = Color.yellow

    /// One hue per metric. No two metrics shown on the Analytics tab share a hue, and none uses a
    /// macro colour (blue, coral, green, yellow).
    ///
    /// | Metric | Hue | Was |
    /// |---|---|---|
    /// | `workouts` | orange | orange |
    /// | `steps` | mint | orange (clashed with workouts) |
    /// | `expenditure` | pink | pink |
    /// | `scaleWeight` | purple | green (scale weight) / purple (weight trend) |
    /// | `bodyFat` | teal | teal |
    /// | `measurements` | brown | green. Not on the Analytics tab; shares brown with nutrition, which never appears beside it |
    /// | `goalProgress` | accent | green. The user's own target, so it is accent, not a metric hue |
    /// | `nutrition` | brown | protein coral |
    /// | `muscleGroups` | indigo | blue (the calories colour) |
    /// | `exercises` | cyan | cyan |
    /// | `habits` | magenta | green/orange/teal per card |
    enum Metric {
        static let workouts = Color.orange
        static let steps = Color.mint
        static let expenditure = Color.pink
        static let scaleWeight = Color.purple
        static let bodyFat = Color.teal
        static let measurements = Color.brown
        static let goalProgress = Color.accentColor
        static let nutrition = Color.brown
        static let muscleGroups = Color.indigo
        static let exercises = Color.cyan
        static let habits = Color(red: 0.8, green: 0.3, blue: 0.75)
    }
}

/// Lets the colour tokens be written as `ShapeStyle`s: `.foregroundStyle(.protein)`.
/// `onAccent` needs no mirror; the asset catalog generates it.
extension ShapeStyle where Self == Color {
    static var surface: Color { Color.surface }
    static var canvas: Color { Color.canvas }
    static var calories: Color { Color.calories }
    static var protein: Color { Color.protein }
    static var carbs: Color { Color.carbs }
    static var fat: Color { Color.fat }
    static var vitamins: Color { Color.vitamins }
    static var minerals: Color { Color.minerals }
    static var otherNutrients: Color { Color.otherNutrients }
    static var success: Color { Color.success }
    static var warning: Color { Color.warning }
    static var danger: Color { Color.danger }
    static var warmup: Color { Color.warmup }
    static var superset: Color { Color.superset }
    static var personalRecord: Color { Color.personalRecord }
}

// MARK: - Preview

private struct PaletteSwatch: View {
    let name: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.m) {
            RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                .fill(color)
                .frame(width: ControlSize.thumbnail, height: ControlSize.thumbnail)
            Text(name).font(.rowTitle)
            Spacer()
            Text(name)
                .font(.label)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xs)
                .background(Color.tintedSurface(color), in: .capsule)
                .foregroundStyle(color)
        }
    }
}

private struct PalettePreview: View {
    var body: some View {
        List {
            Section("Accent") {
                Text("Primary action")
                    .font(.sectionTitle)
                    .foregroundStyle(.onAccent)
                    .frame(maxWidth: .infinity, minHeight: ControlSize.row)
                    .background(.tint, in: .capsule)
                PaletteSwatch(name: "accentColor", color: .accentColor)
            }
            Section("Surfaces") {
                PaletteSwatch(name: "surface", color: .surface)
                PaletteSwatch(name: "canvas", color: .canvas)
            }
            Section("Nutrition") {
                PaletteSwatch(name: "calories", color: .calories)
                PaletteSwatch(name: "protein", color: .protein)
                PaletteSwatch(name: "carbs", color: .carbs)
                PaletteSwatch(name: "fat", color: .fat)
                PaletteSwatch(name: "vitamins", color: .vitamins)
                PaletteSwatch(name: "minerals", color: .minerals)
                PaletteSwatch(name: "otherNutrients", color: .otherNutrients)
            }
            Section("Status and sets") {
                PaletteSwatch(name: "success", color: .success)
                PaletteSwatch(name: "warning", color: .warning)
                PaletteSwatch(name: "danger", color: .danger)
                PaletteSwatch(name: "warmup", color: .warmup)
                PaletteSwatch(name: "superset", color: .superset)
                PaletteSwatch(name: "personalRecord", color: .personalRecord)
            }
            Section("Metrics") {
                PaletteSwatch(name: "workouts", color: Color.Metric.workouts)
                PaletteSwatch(name: "steps", color: Color.Metric.steps)
                PaletteSwatch(name: "expenditure", color: Color.Metric.expenditure)
                PaletteSwatch(name: "scaleWeight", color: Color.Metric.scaleWeight)
                PaletteSwatch(name: "bodyFat", color: Color.Metric.bodyFat)
                PaletteSwatch(name: "measurements", color: Color.Metric.measurements)
                PaletteSwatch(name: "goalProgress", color: Color.Metric.goalProgress)
                PaletteSwatch(name: "nutrition", color: Color.Metric.nutrition)
                PaletteSwatch(name: "muscleGroups", color: Color.Metric.muscleGroups)
                PaletteSwatch(name: "exercises", color: Color.Metric.exercises)
                PaletteSwatch(name: "habits", color: Color.Metric.habits)
            }
        }
    }
}

#Preview("Palette, light") {
    PalettePreview().preferredColorScheme(.light)
}

#Preview("Palette, dark") {
    PalettePreview().preferredColorScheme(.dark)
}
