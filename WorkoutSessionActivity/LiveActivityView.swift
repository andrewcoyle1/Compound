//
//  LiveActivityView.swift
//  DialedIn
//
//  The lock-screen banner (spec: docs/specs/live-activity.md §3).
//
//  One switch, in `LiveActivityPhaseContent`, over the phase derived from the content state.
//  Fixed height across phases at the default text size so the banner does not jump when a set
//  completes (it grows only at larger sizes), two rows, and
//  a 1-pt whole-workout progress line along the bottom edge. No header: no app icon, no workout
//  name outside `.ended`, no elapsed timer, no total volume, no status message.
//

import SwiftUI
import WidgetKit
import AppIntents

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
struct LiveActivityView: View {

    @Environment(\.colorScheme) private var colorScheme

    let context: ActivityViewContext<WorkoutActivityAttributes>

    private var phase: LiveActivityPhase {
        LiveActivityPhase(state: context.state, now: Date(), isStale: context.isStale)
    }

    var body: some View {
        VStack(spacing: 0) {
            LiveActivityPhaseContent(
                phase: phase,
                state: context.state,
                workoutName: context.attributes.workoutName,
                // The widget's accent is `labelColor`, so a prominent label needs the inverse.
                prominentLabelColor: colorScheme.inverseLabel
            )
            .liveActivityContentHeight()
            // The system's standard Lock Screen margin for Live Activities.
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            progressLine
        }
        .dynamicTypeSize(...LiveActivityLayout.maxDynamicTypeSize)
        // A tap opens the tracker, as the Today widget's does.
        .widgetURL(WidgetSnapshotStore.workoutURL)
    }

    /// The only whole-workout indicator: a 1-pt line along the bottom edge.
    private var progressLine: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: proxy.size.width * progressFraction)
            }
        }
        .frame(height: 1)
        .accessibilityElement()
        .accessibilityLabel("Workout progress")
        .accessibilityValue("\(context.state.completedSetsCount) of \(context.state.totalSetsCount) sets")
    }

    private var progressFraction: CGFloat {
        CGFloat(min(max(context.state.progress, 0), 1))
    }
}

#Preview("Banner", as: .content, using: WorkoutActivityAttributes.preview) {
    WorkoutSessionActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.preview(.ready)
    WorkoutActivityAttributes.ContentState.preview(.resting)
    WorkoutActivityAttributes.ContentState.preview(.restOver)
    WorkoutActivityAttributes.ContentState.preview(.allSetsDone)
    WorkoutActivityAttributes.ContentState.preview(.paused)
    WorkoutActivityAttributes.ContentState.preview(.ended)
}
#endif
