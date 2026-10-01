//
//  MacroProgressChart.swift
//  Compound
//
//  Created by Andrew Coyle on 06/02/2026.
//

import SwiftUI

/// One value against its target, for a summary card: QuickCharts' `ProgressThumbnail`, a bar
/// across a track with a tick at the target, which takes no touches.
struct MacroProgressChart: View {
    var current: Double
    var target: Double?
    var maxValue: Double
    var color: Color
    /// Read by VoiceOver after the numbers, e.g. "g" gives "48 of 150 g".
    var unit: String = ""

    var body: some View {
        ProgressThumbnail(value: current, target: target, maxValue: maxValue, color: color)
            .accessibilityElement()
            .accessibilityValue(accessibilitySummary)
    }

    /// "48 of 150 g", or "48 g" with no target.
    private var accessibilitySummary: String {
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1))
        let suffix = unit.isEmpty ? "" : " \(unit)"
        guard let target, target > 0 else { return "\(current.formatted(format))\(suffix)" }
        return String(localized: "\(current.formatted(format)) of \(target.formatted(format))\(suffix)")
    }
}

#Preview("Protein") {
    MacroProgressChart(current: 48.3, target: 150, maxValue: 200, color: Color.protein).padding()
}

#Preview("Over") {
    MacroProgressChart(current: 91.5, target: 80, maxValue: 100, color: Color.carbs).padding()
}
