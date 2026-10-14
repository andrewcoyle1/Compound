//
//  WorkoutCorrectionBar.swift
//  Compound
//
//  The set just logged, over the log button while its rest runs: a rep off or on, reps in reserve
//  and Undo. Off the card, so the set table stays sets only. Shake and ⌘Z still undo after the
//  rest (`WorkoutTrackerPresenter+Correction`).
//

import SwiftUI

struct WorkoutCorrectionBar: View {

    /// The set just logged, while its rest runs; `nil` hides the bar.
    let correction: SetCorrection?
    let onAction: @MainActor (SetCorrectionAction) -> Void

    var body: some View {
        Group {
            if let correction {
                InlineRestTimerRow(timer: nil, correction: correction, onCorrection: onAction)
                    .padding(.vertical, Spacing.xs)
                    .cardSurface()
                    .padding(.horizontal, Spacing.m)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .reducedMotionAnimation(.standard, value: correction)
    }
}
