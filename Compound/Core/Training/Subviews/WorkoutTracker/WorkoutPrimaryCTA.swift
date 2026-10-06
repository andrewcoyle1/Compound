//
//  WorkoutPrimaryCTA.swift
//  Compound
//
//  Split out of WorkoutTrackerView.swift to keep it under the file-length limits, so later work
//  on the log button changes this file rather than the screen's body. The content of the
//  tracker's `.bottomCTA`: Skip Rest and +15s while resting, otherwise the log button.
//

import SwiftUI

// An extension rather than its own `View`: `.bottomCTA` drops the inset when its content has no
// subviews, and it decides that in the parent's body. A child view's body changing (the log
// button appearing once the session loads) does not re-run that, so the button never showed.
extension WorkoutTrackerView {

    @ViewBuilder
    var primaryCTA: some View {
        if let restEnd = presenter.runningRestEnd, !isKeyboardVisible {
            // While resting, the thing to do is end the rest, or lengthen it; the next set's
            // button comes back when it is over.
            HStack(spacing: 0) {
                CallToActionButton {
                    presenter.onSkipRestPressed()
                } label: {
                    HStack(spacing: Spacing.s) {
                        Text("Skip Rest")
                        Text(timerInterval: Date()...restEnd)
                            .monospacedDigit()
                    }
                }
                .accessibilityIdentifier("WorkoutTracker.skipRestButton")

                // The call to action's own metrics, at the width of its label.
                Button {
                    presenter.onAddRestTimePressed()
                } label: {
                    // The label sits on the text, not the button: a label on the button
                    // replaces its children, and the audit then sees text no element owns.
                    Text("+15s")
                        .accessibilityLabel("Add 15 seconds")
                        .padding(.vertical, Spacing.m)
                }
                .buttonStyle(.glass)
                .padding(.trailing)
            }
        } else if presenter.primaryAction != nil, !isKeyboardVisible {
            CallToActionButton {
                presenter.onPrimaryActionPressed()
            } label: {
                Text(presenter.primaryActionTitle)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .accessibilityIdentifier("WorkoutTracker.logButton")
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }
}
