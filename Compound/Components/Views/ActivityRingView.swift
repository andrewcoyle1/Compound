//
//  ActivityRingView.swift
//  Compound
//
//  Created by Andrew Coyle on 08/03/2026.
//

import SwiftUI

struct ActivityRingView: View {
        
    @State private var internalProgress: Double = 0
    /// The ring holds a caption-sized label, so it grows with the caption rather than cropping it.
    @ScaledMetric(relativeTo: .caption) private var textScale: CGFloat = 1

    let text: String
    let imageName: String
    var progress: Double // Value from 0.0 to 1.0+
    let color: Color
    let size: CGFloat
    
    init(
        text: String = "Label",
        imageName: String = "info",
        progress: Double,
        color: Color,
        size: CGFloat
    ) {
        self.text = text
        self.imageName = imageName
        self.progress = progress
        self.color = color
        self.size = size
    }
    
    /// Capped at twice the design size: by then the caption fits inside the ring, and a ring any
    /// larger crowds out whatever sits beside it.
    private var side: CGFloat { size * min(textScale, 2) }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.tintedSurface(color), lineWidth: side / 10)
            
            // Active progress ring
            Circle()
                .trim(from: 0, to: min(self.internalProgress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: side / 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            // Optional: Circle at the tip for better visual
            if progress > 0 {
                Circle()
                    .fill(color)
                    .shadow(radius: Spacing.xs)
                    .frame(width: side / 10, height: side / 10)
                    .offset(y: -side / 2)
                    .rotationEffect(
                        .degrees(min(self.internalProgress, 1.0) * CGFloat(360) /*- CGFloat(90)*/)
                        
                    )
            }
            
            VStack {
                Image(systemName: imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, side/10)
                    .foregroundStyle(color)
                Text(text)
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
            .padding(side/8)
        }
        .frame(width: side, height: side)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityValue(Format.percent(progress))
        .onAppear {
            withReducedMotionAnimation(.progress) {
                internalProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withReducedMotionAnimation(.progress) {
                internalProgress = newValue
            }
        }
    }
}

// Usage Example
#Preview {
    
    LazyVGrid(columns: [GridItem(), GridItem()]) {
        ActivityRingView(progress: 0.25, color: .calories, size: 200)
        ActivityRingView(progress: 0.5, color: .protein, size: 150)
        ActivityRingView(progress: 0.9, color: .carbs, size: 100)
        ActivityRingView(progress: 1, color: .fat, size: 100)
        ActivityRingView(progress: 1, color: .calories, size: 60)
    }
}
