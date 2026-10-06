//
//  WorkoutProgressHeader.swift
//  Compound
//
//  Split out of WorkoutTrackerView.swift to keep it under the file-length limits, so later work
//  on the header changes this file rather than the screen's body.
//

import SwiftUI

/// Working sets done, and which exercise of how many, over a thin bar. Warm-ups are left out.
struct WorkoutProgressHeader: View {

    let presenter: WorkoutTrackerPresenter

    var body: some View {
        let progress = presenter.progress
        return VStack(spacing: Spacing.xs) {
            ProgressView(value: progress.fraction)
            // Fonts on each text, not the stack: the accessibility audit only credits a text with
            // Dynamic Type when its own font is a text style.
            HStack {
                Text("\(progress.doneWorkingSets) of \(progress.totalWorkingSets) working sets")
                    .font(.label)
                Spacer()
                if progress.isSuperset {
                    Text("Superset \(progress.exerciseNumber) of \(progress.exerciseCount)")
                        .font(.label)
                } else {
                    Text("Exercise \(progress.exerciseNumber) of \(progress.exerciseCount)")
                        .font(.label)
                }
            }
            // Primary: secondary on the bar's hard edge fails 4.5:1 at this size.
            .monospacedDigit()
        }
        .padding(.horizontal)
        .padding(.bottom, Spacing.xs)
        // Solid behind the counts: the scroll edge alone let a highlighted row show through.
        .background(Color.canvas)
        .accessibilityElement(children: .combine)
    }
}
