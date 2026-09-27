//
//  MacroProgressChart.swift
//  DialedIn
//
//  Created by Andrew Coyle on 06/02/2026.
//

import SwiftUI

/// A horizontal progress bar chart for macro/nutrient display in analytics cards.
/// Shows current value as a colored fill, with an optional target marker line.
struct MacroProgressChart: View {
    var current: Double
    var target: Double?
    var maxValue: Double
    var color: Color
    /// Read by VoiceOver after the numbers, e.g. "g" gives "48 of 150 g".
    var unit: String = ""
    
    /// Scale for the bar: progress fills from 0 to min(current, maxValue)/maxValue
    private var progress: Double {
        guard maxValue > 0 else { return 0 }
        return min(1, max(0, current / maxValue))
    }
    
    /// Position of target marker as fraction of bar width (0...1)
    private var targetPosition: Double? {
        guard let target = target, target > 0, maxValue > 0 else { return nil }
        return min(1, max(0, target / maxValue))
    }
    
    var body: some View {
        GeometryReader { geo in
            let trackHeight = Spacing.s
            let trackY = (geo.size.height - trackHeight) / 2
            
            ZStack(alignment: .leading) {
                // Track (light grey background)
                Capsule()
                    .fill(.quaternary)
                    .frame(height: trackHeight)
                    .frame(maxWidth: .infinity)
                
                // Progress fill
                Capsule()
                    .fill(color)
                    .frame(width: max(0, geo.size.width * progress), height: trackHeight)
                
                // Target marker (vertical grey line)
                if let targetPos = targetPosition {
                    let xVal = geo.size.width * targetPos
                    let topY = trackY - Spacing.xxs
                    let bottomY = trackY + trackHeight + Spacing.xxs
                    Path { path in
                        path.move(to: CGPoint(x: xVal, y: topY))
                        path.addLine(to: CGPoint(x: xVal, y: bottomY))
                    }
                    .stroke(.secondary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
            }
        }
        .frame(maxWidth: .infinity)
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
    MacroProgressChart(
        current: 48.3,
        target: 150,
        maxValue: 200,
        color: Color.protein
    )
    .frame(height: 36)
    .padding()
}

#Preview("Fat") {
    MacroProgressChart(
        current: 29.2,
        target: 65,
        maxValue: 100,
        color: Color.fat
    )
    .frame(height: 36)
    .padding()
}

#Preview("Carbs") {
    MacroProgressChart(
        current: 91.5,
        target: 250,
        maxValue: 300,
        color: Color.carbs
    )
    .frame(height: 36)
    .padding()
}
