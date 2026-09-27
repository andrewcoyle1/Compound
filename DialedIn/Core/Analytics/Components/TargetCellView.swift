//
//  TargetCellView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/10/2025.
//

import SwiftUI

/// One day of one metric in the weekly target grid: a vertical bar filled to what was eaten, with a
/// tick at the target. Going over is marked with a caret as well as the fill passing the tick, so it
/// never rests on the bar's length alone.
struct TargetCellView: View {
    let value: Double
    let targetValue: Double
    let maxValue: Double
    var tint: Color = .accentColor

    private var clampedProgress: Double {
        guard maxValue > 0 else { return 0 }
        return max(0, min(1, value / maxValue))
    }

    private var targetProgress: Double {
        guard maxValue > 0 else { return 0 }
        return max(0, min(1, targetValue / maxValue))
    }

    private var isOverTarget: Bool {
        targetValue > 0 && value > targetValue
    }

    var body: some View {
        GeometryReader { outerGeo in
            let availableWidth = outerGeo.size.width
            let cellHeight = availableWidth * 1.2 // 1:1.2 width:height aspect ratio
            let progressBarWidth = max(Spacing.s, availableWidth * 0.65)
            let padding = max(Spacing.xs, availableWidth * 0.06)
            // Half the tick's length: it stands a little proud of the bar either side.
            let tickHalfLength = Spacing.xs + Spacing.xxs

            ZStack {
                ZStack {
                    ProgressView(value: clampedProgress)
                        .progressViewStyle(.linear)
                        .tint(tint)
                        .frame(width: progressBarWidth, height: Spacing.s)
                        .padding(padding)
                    GeometryReader { geo in
                        let width: CGFloat = geo.size.width
                        let height: CGFloat = geo.size.height
                        let progress = CGFloat(targetProgress)
                        let xPosition: CGFloat = max(0, min(width, width * progress))
                        Path { path in
                            // A short tick across the track at the target.
                            let halfHeight: CGFloat = height / 2
                            path.move(to: CGPoint(x: xPosition, y: halfHeight - tickHalfLength))
                            path.addLine(to: CGPoint(x: xPosition, y: halfHeight + tickHalfLength))
                        }
                        .stroke(.secondary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .allowsHitTesting(false)
                    }
                    .frame(width: progressBarWidth, height: progressBarWidth)
                    .padding(padding)
                }
                .rotationEffect(.degrees(270))
            }
            .frame(width: availableWidth, height: cellHeight)
            .background(.quaternary, in: .rect(cornerRadius: Radius.s, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if isOverTarget {
                    Image(systemName: "chevron.up")
                        .font(.label)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .padding(Spacing.xxs)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1 / 1.2, contentMode: .fit)
    }
}

#Preview {
    HStack {
        TargetCellView(value: 160, targetValue: 180, maxValue: 220, tint: .protein)
        TargetCellView(value: 200, targetValue: 180, maxValue: 220, tint: .protein)
    }
    .padding()
}
