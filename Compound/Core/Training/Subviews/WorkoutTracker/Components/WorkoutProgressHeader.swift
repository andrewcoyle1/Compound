//
//  WorkoutProgressHeader.swift
//  Compound
//
//  The header under the navigation bar: the exercise strip and the workout's progress.
//

import SwiftUI

/// Working sets done, and which exercise of how many, over a thin bar. Warm-ups are left out.
/// The exercise strip takes the bar's place; at accessibility sizes, where thumbnails cannot carry
/// text, the bar stays and "Exercise 3 of 8" becomes a menu of the blocks.
struct WorkoutProgressHeader: View {

    let progress: ActiveWorkout.Progress
    /// False while paused, which greys the bar.
    let isActive: Bool
    let stripItems: [ActiveWorkout.StripItem]
    /// The card's block, ticked in the accessibility-size menu.
    let currentBlockId: String?
    let onSelect: (String) -> Void
    let onDoNext: (String) -> Void
    let onDoLater: (String) -> Void
    let onMove: (String, Int) -> Void
    let onAddExercise: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: Spacing.xs) {
            if !dynamicTypeSize.isAccessibilitySize {
                ExerciseStrip(
                    items: stripItems,
                    onSelect: onSelect,
                    onDoNext: onDoNext,
                    onDoLater: onDoLater,
                    onMove: onMove,
                    onAddExercise: onAddExercise
                )
            }
            summary
        }
        .padding(.bottom, Spacing.xs)
    }

    /// The counts; at accessibility sizes, over the bar, with the block count as a menu.
    private var summary: some View {
        let isCompact = dynamicTypeSize.isAccessibilitySize
        return VStack(spacing: Spacing.xs) {
            if isCompact {
                ProgressView(value: progress.fraction)
                    // Greyed while paused, with Paused in the title: the workout is not moving on.
                    .tint(isActive ? nil : Color.secondary)
            }
            // Fonts on each text, not the stack: the accessibility audit only credits a text with
            // Dynamic Type when its own font is a text style.
            countsLayout {
                Text("\(progress.doneWorkingSets) of \(progress.totalWorkingSets) working sets")
                    .font(.label)
                if !isCompact {
                    Spacer()
                }
                if isCompact {
                    Menu {
                        blockMenuItems
                    } label: {
                        blockCount(progress)
                    }
                    .accessibilityIdentifier("WorkoutTracker.exerciseMenu")
                } else {
                    blockCount(progress)
                }
            }
            // Primary: secondary on the bar's hard edge fails 4.5:1 at this size.
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .accessibilityElement(children: isCompact ? .contain : .combine)
        // A label, not a control: without the bar it is a 14 pt line, which the audit otherwise
        // reads as a hit area too small to tap.
        .accessibilityRespondsToUserInteraction(isCompact)
    }

    /// The two counts on one line, or one under the other at accessibility sizes, where side by
    /// side each wrapped onto several lines of a bar that stays pinned on screen (a11y.md S3).
    private var countsLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxs))
            : AnyLayout(HStackLayout())
    }

    @ViewBuilder
    private func blockCount(_ progress: ActiveWorkout.Progress) -> some View {
        if progress.isSuperset {
            Text("Superset \(progress.exerciseNumber) of \(progress.exerciseCount)")
                .font(.label)
        } else {
            Text("Exercise \(progress.exerciseNumber) of \(progress.exerciseCount)")
                .font(.label)
        }
    }

    /// The strip's items as a menu, for accessibility sizes, the current block checked.
    private var blockMenuItems: some View {
        Picker("Exercise", selection: Binding(
            get: { currentBlockId ?? "" },
            set: { onSelect($0) }
        )) {
            ForEach(stripItems) { item in
                Text(item.names.formatted(.list(type: .and)))
                    .tag(item.id)
            }
        }
    }
}
