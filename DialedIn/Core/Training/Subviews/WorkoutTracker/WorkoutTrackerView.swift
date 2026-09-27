//
//  WorkoutTrackerView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 23/09/2025.
//

import SwiftUI
import HealthKit
import Combine

struct WorkoutTrackerView<ExerciseTracker: View>: View {

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
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
                CallToActionButton {
                    presenter.onFinishPressed()
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
            LazyVGrid(columns: [GridItem(), GridItem(), GridItem()], alignment: .center, spacing: Spacing.l) {
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
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
        }
    }
    
    // MARK: - Timer Header
    private var timerHeaderView: some View {
        HStack {
            let now = Date()
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label("Rest Timer", systemImage: Symbol.rest)
                    .font(.label)
                    .foregroundStyle(.secondary)
                if let end = presenter.restEndTime,
                   now < end {
                    Text(timerInterval: now...end)
                        .font(.metricLarge)
                } else {
                    Text((presenter.workoutSession.dateCreated), style: .timer)
                        .font(.metricLarge)
                }
            }
            
            Spacer()
        }
        .padding(Spacing.s)
        .padding(.horizontal, Spacing.s)
        .accessibilityElement(children: .combine)
        .glassEffect()
        .padding()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                // No "Resume Workout": the tracker has no paused state to resume from, so the
                // item did nothing. Reinstate it alongside a real pause.
                Button {
                    presenter.minimizeSession()
                } label: {
                    Label("Minimise Tracker", systemImage: "chevron.down")
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
                    Label("Delete Workout", systemImage: Symbol.delete)
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
        let trackerPresenter = try WorkoutTrackerPresenter(
            interactor: interactor,
            router: CoreRouter(router: router, builder: self)
        )
        return WorkoutTrackerView(
            presenter: trackerPresenter,
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
    func showWorkoutTrackerView() {
        router.showScreen(.fullScreenCover) { router in
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
