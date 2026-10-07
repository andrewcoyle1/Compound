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
                    returnFocusToPrimaryCTA()
                } label: {
                    primarySlotLabel
                }
                .accessibilityFocused($isPrimaryCTAFocused)
                .accessibilityInputLabels(presenter.primarySlotInputLabels)
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

    /// A log, a skip or Next redraws the button and the rows above it, and VoiceOver's cursor used
    /// to land wherever the redraw left it, often the top of the screen. It goes back to the
    /// button once the new state is drawn, so the next double tap logs the next set (a11y.md C1).
    /// Without VoiceOver this does nothing.
    func returnFocusToPrimaryCTA() {
        Task { @MainActor in
            // After the redraw: set during it, the focus goes to the element being replaced.
            try? await Task.sleep(for: .milliseconds(300))
            isPrimaryCTAFocused = true
        }
    }

    @ViewBuilder
    private var primarySlotLabel: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        if let restEnd = presenter.primarySlotRestEnd {
            HStack(spacing: Spacing.s) {
                // At accessibility sizes "Skip Rest 1:23" beside +15s would need two more lines
                // in a bar that already covers much of the screen. "Skip" fits beside it, and the
                // rest line in the card shows the clock (S3). VoiceOver hears "Skip rest" either way.
                if isLarge {
                    Text("Skip")
                } else {
                    Text("Skip Rest")
                    Text(timerInterval: min(.now, restEnd)...restEnd)
                        .monospacedDigit()
                }
            }
            // A name Voice Control can say, with the ticking time as its value rather than in it.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presenter.primarySlotTitle)
            .accessibilityValue(Text(timerInterval: min(.now, restEnd)...restEnd))
        } else {
            // At accessibility sizes "Log set 2 · 102.5 kg × 10" needs three lines and lost its
            // figures to the line limit; "Log set 2" fits, and the row above shows the figures (S3).
            Text(isLarge ? presenter.primarySlotShortTitle : presenter.primarySlotTitle)
                .lineLimit(isLarge ? nil : 2)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .accessibilityLabel(presenter.primarySlotTitle)
        }
    }
}
