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

    let presenter: WorkoutTrackerPresenter

    var body: some View {
        Group {
            if let rest = presenter.restCorrection {
                InlineRestTimerRow(timer: nil, correction: rest.correction) { action in
                    presenter.onCorrection(action, setId: rest.correction.setId, in: rest.exerciseId)
                }
                .padding(.vertical, Spacing.xs)
                .cardSurface()
                .padding(.horizontal, Spacing.m)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .reducedMotionAnimation(.standard, value: presenter.restCorrection?.correction)
    }
}
