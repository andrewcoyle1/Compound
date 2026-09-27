//
//  ProgressCircle.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

import SwiftUI

struct ProgressCircle: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State var value: CGFloat
    @State var showValue: Bool = false
    
    var size: CGFloat = 200
    var progress: Double = 0.6
    var color: Color = .blue
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: size/10)
                .frame(width: size, height: size)
                .foregroundStyle(colorScheme.backgroundPrimary)
                .shadow(color: .primary.opacity(0.1), radius: 10, x: 10, y: 10)
            Circle()
                .stroke(lineWidth: 0.34)
                .frame(width: (7/8*size), height: (7/8*size))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.primary.opacity(0.3), .clear]),
                        startPoint: .bottomTrailing,
                        endPoint: .topLeading
                    )
                )
                .overlay {
                    Circle()
                        .stroke(.primary.opacity(0.1), lineWidth: 2)
                        .blur(radius: 5)
                        .mask {
                            Circle()
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.primary, .clear]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                }
            Circle()
                .trim(from: 0, to: showValue ? value : 0.0)
                .stroke(
                    style: StrokeStyle(
                        lineWidth: size/10,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [color, .clear]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

        }
        .onAppear {
            withReducedMotionAnimation(.spring().speed(0.2)) {
                showValue = true
            }
        }
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(), GridItem()]) {
        ProgressCircle(value: 0.75, size: 100, color: .protein)
        ProgressCircle(value: 0.5, size: 50, color: .carbs)
        ProgressCircle(value: 0.25, size: 75, color: .fat)
        ProgressCircle(value: 0.1, size: 25)
        ProgressCircle(value: 0.9, size: 150)
        ProgressCircle(value: 1)
    }
}
