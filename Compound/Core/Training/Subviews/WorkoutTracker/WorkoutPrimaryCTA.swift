//
//  WorkoutPrimaryCTA.swift
//  Compound
//
//  Split out of WorkoutTrackerView.swift to keep it under the file-length limits, so later work
//  on the log button changes this file rather than the screen's body. The content of the
//  tracker's `.bottomCTA`: one button that logs, skips the rest, moves on, finishes or resumes,
//  with +15s beside it while resting.
//

import SwiftUI

// An extension rather than its own `View`: `.bottomCTA` drops the inset when its content has no
// subviews, and it decides that in the parent's body. A child view's body changing (the log
// button appearing once the session loads) does not re-run that, so the button never showed.
extension WorkoutTrackerView {

    @ViewBuilder
    var primaryCTA: some View {
        if presenter.primarySlot != nil {
            HStack(spacing: 0) {
                // One button for every action, so its capsule morphs from Log to Skip Rest and back
                // rather than one button leaving as another arrives, and VoiceOver focus stays on it.
                CallToActionButton {
                    presenter.onPrimarySlotPressed()
                } label: {
                    primarySlotLabel
                }
                .disabled(presenter.isPrimarySlotInGrace)
                .keyboardShortcut(.return, modifiers: .command)
                // Two identifiers for the one button, so tests can wait for the state they need.
                .accessibilityIdentifier(presenter.primarySlotRestEnd == nil ? "WorkoutTracker.logButton" : "WorkoutTracker.skipRestButton")

                if presenter.primarySlotRestEnd != nil {
                    // As wide as Skip Rest: style, not size, says which is preferred.
                    CallToActionButton(isPrimaryAction: false) {
                        presenter.onAddRestTimePressed()
                    } label: {
                        // The label sits on the text, not the button: a label on the button
                        // replaces its children, and the audit then sees text no element owns.
                        Text("+15s")
                            .accessibilityLabel("Add 15 seconds")
                    }
                    .accessibilityInputLabels(["Plus 15", "Add 15 seconds"])
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.85, anchor: .leading).combined(with: .opacity))
                }
            }
            // Scoped to the button: the list beneath animates only what changed in it.
            .reducedMotionAnimation(.standard, value: presenter.primarySlot)
            .reducedMotionAnimation(.emphasis, value: presenter.canQuickFinish)
        }
    }

    @ViewBuilder
    private var primarySlotLabel: some View {
        if let restEnd = presenter.primarySlotRestEnd {
            HStack(spacing: Spacing.s) {
                Text("Skip Rest")
                Text(timerInterval: min(.now, restEnd)...restEnd)
                    .monospacedDigit()
            }
            // A name Voice Control can say, with the ticking time as its value rather than in it.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presenter.primarySlotTitle)
            .accessibilityValue(Text(timerInterval: min(.now, restEnd)...restEnd))
        } else {
            Text(presenter.primarySlotTitle)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
        }
    }
}
