//
//  WorkoutSessionActivity.swift
//  WorkoutSessionActivity
//
//  Created by Andrew Coyle on 30/09/2025.
//
//  The Dynamic Island (spec: docs/specs/live-activity.md §5). Every region switches on the
//  same `LiveActivityPhase` the banner uses. The island always renders on black, so it uses
//  semantic colours and never reads the colour scheme.
//

import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
struct WorkoutSessionActivity: Widget {

    /// The widget's accent is `labelColor`; on the island's black background that resolves
    /// light, so a label on a `.borderedProminent` button is drawn dark.
    private static let islandProminentLabelColor = Color.black

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    expandedContent(context: context)
                }
            } compactLeading: {
                compactLeading(context: context)
            } compactTrailing: {
                compactTrailing(context: context)
            } minimal: {
                minimal(context: context)
            }
            // The same link as the banner: a tap opens the tracker, not wherever the app was left.
            .widgetURL(WidgetSnapshotStore.workoutURL)
            .keylineTint(Color.accentColor)
        }
    }

    private func phase(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> LiveActivityPhase {
        LiveActivityPhase(state: context.state, now: Date(), isStale: context.isStale)
    }

    // MARK: - Expanded

    /// The banner's two rows for the current phase, minus the progress line and minus
    /// `.ended` — the island is dismissed when the workout ends.
    private func expandedContent(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        LiveActivityPhaseContent(
            phase: phase(context),
            state: context.state,
            workoutName: context.attributes.workoutName,
            prominentLabelColor: Self.islandProminentLabelColor,
            showsEnded: false
        )
        .padding(.horizontal, 4)
    }

    // MARK: - Compact and minimal

    @ViewBuilder
    private func compactLeading(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        switch phase(context) {
        case let .resting(until, _, _, _):
            RestRing(until: until, size: 18, showsCountdown: false)
                .accessibilityLabel("Resting")
        default:
            ExerciseImage(imageName: context.state.currentExerciseImageName, size: 20)
                .accessibilityLabel(exerciseLabel(context))
        }
    }

    /// What VoiceOver hears for the island's image, which is the only content when minimal.
    private func exerciseLabel(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> Text {
        context.state.currentExerciseName.map { Text(verbatim: $0) } ?? Text("Workout")
    }

    @ViewBuilder
    private func compactTrailing(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        switch phase(context) {
        case let .ready(target, _):
            compactTargetLabel(target, unit: context.state.weightUnit)
        case let .restOver(next):
            compactTargetLabel(next, unit: context.state.weightUnit)
        case let .resting(until, _, _, _):
            Text(timerInterval: Date()...max(until, Date()), countsDown: true)
                .monospacedDigit()
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: 44)
        case .allSetsDone:
            Text("Done")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func compactTargetLabel(_ target: LiveActivitySetTarget, unit: LiveActivityWeightUnit) -> some View {
        if let label = target.label(weightUnit: unit) {
            Text(label)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func minimal(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        switch phase(context) {
        case let .resting(until, _, _, _):
            RestRing(until: until, size: 18, showsCountdown: false)
                .accessibilityLabel("Resting")
        case .allSetsDone:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("All sets complete")
        default:
            ExerciseImage(imageName: context.state.currentExerciseImageName, size: 18)
                .accessibilityLabel(exerciseLabel(context))
        }
    }
}

extension WorkoutActivityAttributes {
    static let preview = WorkoutActivityAttributes(sessionId: "preview", workoutName: "Chest Workout")
}

extension WorkoutActivityAttributes.ContentState {
    /// The phases the banner and island have, one preview state each (spec §2).
    enum PreviewPhase: CaseIterable {
        case ready, resting, restOver, allSetsDone, paused, ended
    }

    /// Mid-workout on the third set of bench press, then whatever `phase` needs changed.
    static func preview(_ phase: PreviewPhase) -> WorkoutActivityAttributes.ContentState {
        var state = WorkoutActivityAttributes.ContentState(
            isActive: phase != .paused,
            completedSetsCount: 5,
            totalSetsCount: 12,
            currentExerciseName: "Bench Press",
            currentExerciseImageName: "BarbellBenchPress",
            currentExerciseIndex: 1,
            totalExercisesCount: 4,
            currentExerciseCompletedSetsCount: 2,
            currentExerciseTotalSetsCount: 4,
            targetSetId: "set-3",
            targetWeightKg: 100,
            targetReps: 8,
            targetDistanceMeters: nil,
            targetDurationSec: nil,
            restEndsAt: nil,
            progress: 5.0 / 12.0,
            isWorkoutEnded: false,
            finalDurationSeconds: nil,
            finalVolumeKg: nil,
            finalCompletedSetsCount: nil,
            isProcessingIntent: false,
            isAllSetsComplete: false
        )
        switch phase {
        case .ready, .paused:
            break
        case .resting:
            state.restEndsAt = Date().addingTimeInterval(45)
            state.lastLoggedSetId = "set-2"
            state.lastLoggedReps = 8
            state.lastLoggedWeightKg = 100
        case .restOver:
            state.restEndsAt = Date().addingTimeInterval(-5)
        case .allSetsDone:
            state.completedSetsCount = 12
            state.currentExerciseCompletedSetsCount = 4
            state.targetSetId = nil
            state.progress = 1
            state.isAllSetsComplete = true
        case .ended:
            state.isWorkoutEnded = true
            state.finalDurationSeconds = 52 * 60
            state.finalVolumeKg = 4_250
            state.finalCompletedSetsCount = 12
        }
        return state
    }
}

#Preview("Island", as: .dynamicIsland(.expanded), using: WorkoutActivityAttributes.preview) {
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
