//
//  WorkoutProgressHeader.swift
//  Compound
//
//  Split out of WorkoutTrackerView.swift to keep it under the file-length limits, so later work
//  on the header changes this file rather than the screen's body.
//

import SwiftUI

/// Working sets done, and which exercise of how many, over a thin bar. Warm-ups are left out.
/// With the exercise strip on, the strip takes the bar's place; at accessibility sizes, where
/// thumbnails cannot carry text, the bar stays and "Exercise 3 of 8" becomes a menu of the blocks.
struct WorkoutProgressHeader: View {

    let presenter: WorkoutTrackerPresenter

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let showsStrip = presenter.showsExerciseStrip
        let showsThumbnails = showsStrip && !dynamicTypeSize.isAccessibilitySize
        return VStack(spacing: Spacing.xs) {
            if showsThumbnails {
                ExerciseStrip(
                    items: presenter.stripItems,
                    onSelect: presenter.onStripItemSelected,
                    onDoNext: presenter.onDoNextPressed,
                    onDoLater: presenter.onDoLaterPressed,
                    onAddExercise: presenter.presentAddExercise
                )
            }
            summary(showsBar: !showsThumbnails, blockMenu: showsStrip && !showsThumbnails)
        }
        .padding(.bottom, Spacing.xs)
        // Solid behind the counts: the scroll edge alone let a highlighted row show through. With
        // the strip on, the automatic scroll edge effect does that job instead.
        .background(showsStrip ? Color.clear : Color.canvas)
    }

    private func summary(showsBar: Bool, blockMenu: Bool) -> some View {
        let progress = presenter.progress
        return VStack(spacing: Spacing.xs) {
            if showsBar {
                ProgressView(value: progress.fraction)
                    // Greyed while paused, with Paused in the title: the workout is not moving on.
                    .tint(presenter.isActive ? nil : Color.secondary)
            }
            // Fonts on each text, not the stack: the accessibility audit only credits a text with
            // Dynamic Type when its own font is a text style.
            countsLayout {
                Text("\(progress.doneWorkingSets) of \(progress.totalWorkingSets) working sets")
                    .font(.label)
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }
                if blockMenu {
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
        .accessibilityElement(children: blockMenu ? .contain : .combine)
        // A label, not a control: without the bar it is a 14 pt line, which the audit otherwise
        // reads as a hit area too small to tap.
        .accessibilityRespondsToUserInteraction(blockMenu)
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
            get: { presenter.currentBlockId ?? "" },
            set: { presenter.onStripItemSelected($0) }
        )) {
            ForEach(presenter.stripItems) { item in
                Text(item.names.formatted(.list(type: .and)))
                    .tag(item.id)
            }
        }
    }
}
