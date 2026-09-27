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
            let trackHeight: CGFloat = 8
            let trackY = (geo.size.height - trackHeight) / 2
            
            ZStack(alignment: .leading) {
                // Track (light grey background)
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: trackHeight)
                    .frame(maxWidth: .infinity)
                
                // Progress fill
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(color)
                    .frame(width: max(0, geo.size.width * progress), height: trackHeight)
                
                // Target marker (vertical grey line)
                if let targetPos = targetPosition {
                    let xVal = geo.size.width * targetPos
                    let topY = trackY - CGFloat(2)
                    let bottomY = trackY + trackHeight + CGFloat(2)
                    Path { path in
                        path.move(to: CGPoint(x: xVal, y: topY))
                        path.addLine(to: CGPoint(x: xVal, y: bottomY))
                    }
                    .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
            }
        }
        .frame(maxWidth: .infinity)
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
