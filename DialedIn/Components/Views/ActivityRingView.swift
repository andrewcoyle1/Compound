//
//  ActivityRingView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

import SwiftUI

struct ActivityRingView: View {
        
    @State private var internalProgress: Double = 0

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
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.tintedSurface(color), lineWidth: size / 10)
            
            // Active progress ring
            Circle()
                .trim(from: 0, to: min(self.internalProgress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: size / 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            // Optional: Circle at the tip for better visual
            if progress > 0 {
                Circle()
                    .fill(color)
                    .shadow(radius: Spacing.xs)
                    .frame(width: size / 10, height: size / 10)
                    .offset(y: -size / 2)
                    .rotationEffect(
                        .degrees(min(self.internalProgress, 1.0) * CGFloat(360) /*- CGFloat(90)*/)
                        
                    )
            }
            
            VStack {
                Image(systemName: imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, size/10)
                    .foregroundStyle(color)
                Text(text)
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
            .padding(size/8)
        }
        .frame(width: size, height: size)
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
