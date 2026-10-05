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

    @ViewBuilder var exerciseTrackerView: (ExerciseTrackerDelegate, ((Int) -> Void)?) -> ExerciseTracker
    
    var body: some View {
        List {
            workoutOverviewCard
            exerciseSection
        }
        .navigationTitle(presenter.workoutSession.name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .environment(\.editMode, $presenter.editMode)
        .onChange(of: presenter.pendingSelectedTemplates) { _, newValue in
            guard !newValue.isEmpty else { return }
            presenter.addSelectedExercises()
        }
        .toolbar {
            toolbarContent
        }
        .safeAreaInset(edge: .bottom) {
            if presenter.isRestActive {
                timerHeaderView
            }
        }
        // Outside the rest pill's inset, so the button sits at the bottom edge and the pill above it.
        .bottomCTA {
            if presenter.canQuickFinish {
                // Straight to the summary, where notes can still be added. The menu's Finish keeps
                // the notes sheet.
                CallToActionButton {
                    presenter.onFinishConfirmed()
                } label: {
                    Text("Finish Workout")
                }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .reducedMotionAnimation(.emphasis, value: presenter.canQuickFinish)
        .onChange(of: presenter.canQuickFinish) { _, isAvailable in
            presenter.onQuickFinishAvailabilityChanged(isAvailable)
        }
        .task {
            await presenter.observeRestCompletions()
        }
        .task {
            await presenter.onAppear()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            presenter.onScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
    }

    // MARK: - UI Components
    
    // MARK: - Workout Overview Card
    private var workoutOverviewCard: some View {
        Section {
            // Two columns at accessibility sizes, where three squeezed each stat to a word a line.
            LazyVGrid(columns: Array(repeating: GridItem(), count: dynamicTypeSize.isAccessibilitySize ? 2 : 3), alignment: .center, spacing: Spacing.l) {
                Stat(value: presenter.exercisesCount, label: String(localized: "Current Workout"), size: .small, alignment: .center)
                Stat(value: presenter.completedSetsFraction, label: String(localized: "Sets Completed"), size: .small, alignment: .center)
                TimelineView(.periodic(from: presenter.workoutSession.dateCreated, by: 1)) { context in
                    Stat(value: presenter.elapsedTime(at: context.date), label: String(localized: "Elapsed Time"), size: .small, alignment: .center)
                }
                Stat(value: presenter.exerciseFraction, label: String(localized: "Exercise"), size: .small, alignment: .center)
                Stat(value: presenter.formattedVolume, label: String(localized: "Volume"), size: .small, alignment: .center)
                Button {
                    presenter.presentWorkoutNotes()
                } label: {
                    Stat(value: presenter.notesSummary, label: String(localized: "Notes"), size: .small, alignment: .center)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Workout Overview")
        }
        .listSectionMargins(.top, 0)
    }

    // MARK: - Exercise Section Card

    private var exerciseSection: some View {
        // Exercise List
        Section {
            if presenter.workoutSession.exercises.isEmpty {
                ContentUnavailableView {
                    Text("No Exercises")
                } description: {
                    Text("Please add some exercises to get started.")
                }
                .removeListRowFormatting()
            } else {
                ForEach($presenter.workoutSession.exercises) { $exercise in
                    let exerciseId = exercise.id
                    let isExpanded = Binding<Bool>(
                        get: { presenter.expandedExerciseId == exerciseId },
                        set: { presenter.onExerciseExpansionChanged(exerciseId: exerciseId, isExpanded: $0) }
                    )
                    let supersetLabel: String? = {
                        guard let groupId = exercise.supersetGroupId else { return nil }
                        let group = presenter.workoutSession.exercises.filter { $0.supersetGroupId == groupId }
                        let letters = ["A", "B", "C", "D", "E", "F"]
                        guard let idx = group.firstIndex(where: { $0.id == exercise.id }),
                              idx < letters.count else { return nil }
                        let prefix = group.count > 2 ? String(localized: "Circuit") : String(localized: "Superset")
                        return "\(prefix) \(letters[idx])"
                    }()
                    let delegate = ExerciseTrackerDelegate(
                        exercise: $exercise,
                        lastExercise: presenter.previousExercises[exercise.templateId],
                        isExpanded: isExpanded,
                        allWorkoutExercises: presenter.workoutSession.exercises,
                        supersetLabel: supersetLabel,
                        progressionHint: presenter.progressionHint(for: exerciseId),
                        progressionSuggestion: presenter.progressionSuggestions[exercise.templateId],
                        previousNote: presenter.previousNote(forExerciseTemplateId: exercise.templateId),
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
                        }
                    )
                    exerciseTrackerView(delegate, { duration in
                        presenter.startRestTimer(durationSeconds: duration)
                    })
                }
                .onMove { source, destination in
                    presenter.moveExercises(from: source, to: destination)
                }
            }
        } header: {
            HStack {
                Text("Exercises")
                Spacer()
                Button {
                    presenter.presentAddExercise()
                } label: {
                    Image(systemName: Symbol.add)
                }
                .accessibilityLabel("Add exercise")
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
            }
        }
    }
    
    // MARK: - Timer Header
    /// Drawn only while a rest runs (`isRestActive`), with the same +15s and Skip the Lock Screen
    /// offers, so ending a rest early does not mean locking the phone.
    private var timerHeaderView: some View {
        HStack(spacing: Spacing.s) {
            let now = Date()
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label("Rest Timer", systemImage: Symbol.rest)
                    .font(.label)
                    .foregroundStyle(.secondary)
                Text(timerInterval: now...max(presenter.restEndTime ?? now, now))
                    .font(.metricLarge)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            Button {
                presenter.onAddRestTimePressed()
            } label: {
                Text("+15s")
                    .tapTarget()
            }
            .accessibilityLabel("Add 15 seconds")

            Button {
                presenter.onSkipRestPressed()
            } label: {
                Text("Skip")
                    .tapTarget()
            }
            .accessibilityLabel("Skip rest")
        }
        .font(.rowTitle.weight(.semibold))
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .padding(Spacing.s)
        .padding(.horizontal, Spacing.s)
        .glassEffect()
        .padding()
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

                Button {
                    presenter.onFinishPressed()
                } label: {
                    Label("Finish Workout", systemImage: "checkmark")
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
