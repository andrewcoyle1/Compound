//
//  WorkoutTrackerView+Toolbar.swift
//  Compound
//
//  Split out of WorkoutTrackerView.swift to keep it under the file-length limits, so later work
//  adds its views in their own files. The navigation bar: the way out, the title and clock, and
//  the workout's menu.
//

import SwiftUI

extension WorkoutTrackerView {

    /// The workout's name over its date and running clock. Paused time is left out of the clock.
    var titleView: some View {
        VStack(spacing: 0) {
            Text(presenter.workoutSession.name)
                .font(.rowTitle.weight(.semibold))
                .lineLimit(1)
            TimelineView(.periodic(from: presenter.workoutSession.dateCreated, by: 1)) { context in
                // Primary, not secondary: on the glass bar secondary falls just short of 4.5:1.
                Text("\(presenter.workoutDateText) · \(presenter.elapsedTime(at: context.date))")
                    .font(.label)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        // The navigation bar caps its text size, as it does for every app; a long press shows the
        // title and clock at the user's size instead.
        .accessibilityShowsLargeContentViewer()
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        // A chevron rather than `role: .close`: the workout keeps running behind it. A full-screen
        // cover cannot be swiped away, so this is the visible way out.
        ToolbarItem(placement: .cancellationAction) {
            Button {
                presenter.minimizeSession()
            } label: {
                Image(systemName: "chevron.down")
            }
            .accessibilityLabel("Minimize workout")
        }
        ToolbarItem(placement: .principal) {
            titleView
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    presenter.onPauseResumePressed()
                } label: {
                    if presenter.isActive {
                        Label("Pause Workout", systemImage: "pause")
                    } else {
                        Label("Resume Workout", systemImage: "play")
                    }
                }

                // Finishing early. Once every set is logged the button at the foot of the screen
                // reads Finish Workout instead.
                Button {
                    presenter.onFinishPressed()
                } label: {
                    Label("Finish Workout", systemImage: Symbol.selected)
                }

                Button {
                    presenter.presentWorkoutNotes()
                } label: {
                    Label("Workout Notes", systemImage: Symbol.note)
                }

                Button {
                    presenter.onWorkoutSettingsPressed()
                } label: {
                    Label("Workout Settings", systemImage: Symbol.settings)
                }

                Button {
                    presenter.onGymProfilePressed()
                } label: {
                    Label("Gym Settings", systemImage: Symbol.gym)
                }

                Button(role: .destructive) {
                    presenter.onDiscardWorkoutPressed()
                } label: {
                    Label("Discard Workout", systemImage: Symbol.delete)
                }
            } label: {
                Image(systemName: Symbol.more)
            }
            .accessibilityLabel("Workout options")
        }
    }
}
