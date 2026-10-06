//
//  WorkoutTrackerView.swift
//  Compound
//
//  Created by Andrew Coyle on 23/09/2025.
//

import SwiftUI
import HealthKit
import Combine

struct WorkoutTrackerView<ExerciseTracker: View>: View {

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State var presenter: WorkoutTrackerPresenter
    /// The set keyboard has its own Done, which logs the set, so the log button steps aside rather
    /// than riding up over the row being edited.
    @State private var isKeyboardVisible = false

    @ViewBuilder var exerciseTrackerView: (ExerciseTrackerDelegate, ((Int) -> Void)?) -> ExerciseTracker
    
    var body: some View {
        List {
            if presenter.workoutSession.exercises.isEmpty {
                ContentUnavailableView {
                    Text("No Exercises")
                } description: {
                    Text("Please add some exercises to get started.")
                }
                .removeListRowFormatting()
            } else {
                currentExerciseSection
                upNextSection
                completedSection
            }
            addExerciseSection
        }
        .navigationTitle(presenter.workoutSession.name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        // The rest timer and the column headings are a line of text each, not a 44 pt row. Every
        // control in the table carries its own 44 pt hit area.
        .environment(\.defaultMinListRowHeight, Spacing.xl)
        .environment(\.editMode, $presenter.editMode)
        .onChange(of: presenter.pendingSelectedTemplates) { _, newValue in
            guard !newValue.isEmpty else { return }
            presenter.addSelectedExercises()
        }
        .toolbar {
            toolbarContent
        }
        .safeAreaBar(edge: .top) {
            progressHeader
        }
        // Hard, so a scrolled set table never shows through the progress text at large sizes.
        .scrollEdgeEffectStyle(.hard, for: .top)
        .bottomCTA {
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
        .reducedMotionAnimation(.emphasis, value: presenter.canQuickFinish)
        .reducedMotionAnimation(.standard, value: presenter.runningRestEnd == nil)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onChange(of: presenter.canQuickFinish) { _, isAvailable in
            presenter.onQuickFinishAvailabilityChanged(isAvailable)
        }
        .task {
            await presenter.observeRestCompletions()
        }
        .task {
            await presenter.onAppear()
        }
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            presenter.onScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
    }

    // MARK: - Header

    /// Working sets done, and which exercise of how many, over a thin bar. Warm-ups are left out.
    private var progressHeader: some View {
        let progress = presenter.progress
        return VStack(spacing: Spacing.xs) {
            ProgressView(value: progress.fraction)
            // Fonts on each text, not the stack: the accessibility audit only credits a text with
            // Dynamic Type when its own font is a text style.
            HStack {
                Text("\(progress.doneWorkingSets) of \(progress.totalWorkingSets) working sets")
                    .font(.label)
                Spacer()
                Text("Exercise \(progress.exerciseNumber) of \(progress.exerciseCount)")
                    .font(.label)
            }
            // Primary: secondary on the bar's hard edge fails 4.5:1 at this size.
            .monospacedDigit()
        }
        .padding(.horizontal)
        .padding(.bottom, Spacing.xs)
        // Solid behind the counts: the scroll edge alone let a highlighted row show through.
        .background(Color.canvas)
        .accessibilityElement(children: .combine)
    }

    /// The workout's name over its date and running clock. Paused time is left out of the clock.
    private var titleView: some View {
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

    // MARK: - Exercises

    @ViewBuilder
    private var currentExerciseSection: some View {
        if let current = presenter.currentExercise {
            // By id, not index: a binding by index can be read while the exercise it held is being
            // removed, and would then point at another exercise or past the end.
            let exercise = Binding(
                get: { presenter.workoutSession.exercises.first { $0.id == current.id } ?? current },
                set: { updated in
                    guard let index = presenter.workoutSession.exercises.firstIndex(where: { $0.id == current.id }) else { return }
                    presenter.workoutSession.exercises[index] = updated
                }
            )
            Section {
                exerciseTrackerView(delegate(for: exercise), { duration in
                    presenter.startRestTimer(durationSeconds: duration)
                })
            }
            .listSectionMargins(.top, Spacing.s)
        }
    }

    @ViewBuilder
    private var upNextSection: some View {
        let upNext = presenter.upNextExercises
        if !upNext.isEmpty {
            Section {
                ForEach(upNext) { exercise in
                    exerciseRow(exercise, isDone: false)
                }
                .onMove { source, destination in
                    presenter.moveUpNext(from: source, to: destination)
                }
                // Drag handles on demand: a long press on a row is its Do Next / Do Later menu.
                if upNext.count > 1 {
                    Button {
                        presenter.onReorderPressed()
                    } label: {
                        Label(
                            presenter.editMode.isEditing ? "Done Reordering" : "Reorder",
                            systemImage: presenter.editMode.isEditing ? Symbol.success : Symbol.reorder
                        )
                        .font(.rowTitle)
                    }
                    .accessibilityIdentifier("WorkoutTracker.reorderButton")
                }
            } header: {
                Text("Up Next")
                    .font(.label.weight(.semibold))
            }
        }
    }

    @ViewBuilder
    private var completedSection: some View {
        let completed = presenter.completedExercises
        if !completed.isEmpty {
            Section {
                ForEach(completed) { exercise in
                    exerciseRow(exercise, isDone: true)
                }
            } header: {
                Text("Completed")
                    .font(.label.weight(.semibold))
            }
        }
    }

    /// One line per exercise not on the card. A tap opens it on the card.
    private func exerciseRow(_ exercise: WorkoutExerciseModel, isDone: Bool) -> some View {
        Button {
            presenter.onExerciseSelected(exercise.id)
        } label: {
            ListRow(
                title: exercise.name,
                subtitle: presenter.upNextSummary(for: exercise),
                imageName: exercise.imageName,
                resizingMode: .fit,
                initialsWhenMissing: true,
                accessory: isDone
                    ? .custom(AnyView(Image(systemName: Symbol.success).foregroundStyle(.success).accessibilityLabel("Done")))
                    : .chevron
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this exercise")
        // Waiting on a machine: bring an exercise forward, or put it off, without dragging.
        .contextMenu {
            if !isDone {
                Button {
                    presenter.onDoNextPressed(exercise.id)
                } label: {
                    Label("Do Next", systemImage: Symbol.doNext)
                }
                Button {
                    presenter.onDoLaterPressed(exercise.id)
                } label: {
                    Label("Do Later", systemImage: Symbol.doLater)
                }
            }
        }
    }

    private var addExerciseSection: some View {
        Section {
            Button {
                presenter.presentAddExercise()
            } label: {
                Label("Add Exercise", systemImage: Symbol.add)
            }
        }
    }

    /// "Superset A", "Circuit C": the exercise's letter within its group.
    private func supersetLabel(for exercise: WorkoutExerciseModel) -> String? {
        guard let groupId = exercise.supersetGroupId else { return nil }
        let group = presenter.workoutSession.exercises.filter { $0.supersetGroupId == groupId }
        let letters = ["A", "B", "C", "D", "E", "F"]
        guard let idx = group.firstIndex(where: { $0.id == exercise.id }), idx < letters.count else { return nil }
        let prefix = group.count > 2 ? String(localized: "Circuit") : String(localized: "Superset")
        return "\(prefix) \(letters[idx])"
    }

    private func delegate(for exercise: Binding<WorkoutExerciseModel>) -> ExerciseTrackerDelegate {
        let current = exercise.wrappedValue
        let exerciseId = current.id
        var onDoLater: (@MainActor () -> Void)?
        if presenter.canDoLater(current) {
            onDoLater = { presenter.onDoLaterPressed(exerciseId) }
        }
        return ExerciseTrackerDelegate(
            exercise: exercise,
            lastExercise: presenter.previousExercises[current.templateId],
            isExpanded: .constant(true),
            allWorkoutExercises: presenter.workoutSession.exercises,
            supersetLabel: supersetLabel(for: current),
            progressionSuggestion: presenter.progressionSuggestions[current.templateId],
            previousNote: presenter.previousNote(forExerciseTemplateId: current.templateId),
            onSetSupersetGroup: { exerciseId, groupId in
                presenter.setSupersetGroupId(groupId, forExerciseId: exerciseId)
            },
            onDeleteExercise: {
                presenter.deleteExercise(exerciseId)
            },
            onSetCompleted: { completedSet, _ in
                presenter.applyLiveProgression(after: completedSet, in: exerciseId)
            },
            onUpdateNote: { note in
                presenter.updateExerciseNotes(note, exerciseId: exerciseId)
            },
            card: ExerciseCard(
                progressionNote: presenter.progressionNote,
                onProgressionNoteAcknowledged: { presenter.onProgressionNoteAcknowledged() },
                restTimer: presenter.restTimer(for: current),
                onDoLater: onDoLater,
                onLogSet: { setId, customRest in
                    presenter.logSet(setId, in: exerciseId, customRestSeconds: customRest, source: "row")
                },
                onCustomRestChanged: { setId, seconds in
                    presenter.customRestSeconds[setId] = seconds
                }
            )
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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

extension CoreBuilder {
    func workoutTrackerView(router: AnyRouter) throws -> some View {
        WorkoutTrackerView(
            presenter: try WorkoutTrackerPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            exerciseTrackerView: { delegate, onStartRest in
                self.exerciseTrackerView(
                    router: router,
                    delegate: delegate,
                    onStartRest: onStartRest
                )
            }
        )
    }
}

extension CoreRouter {
    /// The screen id the tracker is presented under, so a second request can see it is up.
    static let workoutTrackerScreenId = "workout-tracker"

    /// Pushed on the tracker's own stack when the workout is finished, so the cover ends on what
    /// was done rather than closing and opening a second modal. The one-time Strava offer goes
    /// from the summary's router so the dialog lands over it.
    func showWorkoutSummary(session: WorkoutSessionModel) {
        router.showScreen(.push) { router in
            builder.workoutSessionDetailView(
                router: router,
                delegate: WorkoutSessionDetailDelegate(workoutSession: session, isWorkoutSummary: true)
            )
            .task {
                await CoreRouter(router: router, builder: builder).offerStravaIfFirstWorkout(session)
            }
        }
    }

    /// Every way into the tracker comes through here: the Live Activity, the widget, Training,
    /// Search. A tap on the Live Activity while the tracker is already open must not stack a
    /// second tracker on it, and with no workout under way the builder throws, which used to
    /// present an empty cover with no way out.
    func showWorkoutTrackerView() {
        guard !router.activeScreens.allScreens.contains(where: { $0.id == Self.workoutTrackerScreenId }) else { return }
        guard builder.interactor.activeSession != nil else {
            showSimpleAlert(
                title: String(localized: "No Workout in Progress"),
                subtitle: String(localized: "Start a workout from Training.")
            )
            return
        }
        router.showScreen(.fullScreenCover, id: Self.workoutTrackerScreenId) { router in
            try? builder.workoutTrackerView(router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        try? builder.workoutTrackerView(router: router)
    }
}
