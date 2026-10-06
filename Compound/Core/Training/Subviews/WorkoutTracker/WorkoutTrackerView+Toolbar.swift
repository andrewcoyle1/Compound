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

    /// The workout's name over its date and running clock. Paused time is left out of the clock,
    /// and while paused the clock gives way to Paused.
    var titleView: some View {
        VStack(spacing: 0) {
            Text(presenter.workoutSession.name)
                .font(.rowTitle.weight(.semibold))
                .lineLimit(1)
            TimelineView(.periodic(from: presenter.workoutSession.dateCreated, by: 1)) { context in
                // Primary, not secondary: on the glass bar secondary falls just short of 4.5:1.
                Text("\(presenter.workoutDateText) · \(presenter.clockText(at: context.date))")
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
        // On iPad the bar has room for the workout's controls; the system moves any that do not
        // fit into its overflow menu.
        if horizontalSizeClass == .regular {
            ToolbarItem(placement: .primaryAction) {
                pauseResumeButton
            }
            ToolbarItem(placement: .primaryAction) {
                finishButton
            }
            ToolbarItem(placement: .primaryAction) {
                notesButton
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if horizontalSizeClass != .regular {
                    pauseResumeButton
                    finishButton
                    Divider()
                    notesButton
                }

                Button {
                    presenter.onWorkoutSettingsPressed()
                } label: {
                    Label("Workout Settings", systemImage: Symbol.settings)
                }

                if presenter.hasGymProfile {
                    Button {
                        presenter.onGymProfilePressed()
                    } label: {
                        Label("Gym Settings", systemImage: Symbol.gym)
                    }
                }

                Divider()

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

    private var pauseResumeButton: some View {
        Button {
            presenter.onPauseResumePressed()
        } label: {
            if presenter.isActive {
                Label("Pause Workout", systemImage: "pause")
            } else {
                Label("Resume Workout", systemImage: Symbol.start)
            }
        }
    }

    /// Finishing early. Once every set is logged the button at the foot of the screen offers
    /// Finish Workout as well. Both open the notes sheet first, hence the ellipsis.
    private var finishButton: some View {
        Button {
            presenter.onFinishPressed()
        } label: {
            Label("Finish Workout…", systemImage: Symbol.selected)
        }
    }

    private var notesButton: some View {
        Button {
            presenter.presentWorkoutNotes()
        } label: {
            Label("Workout Notes…", systemImage: Symbol.note)
        }
    }
}
