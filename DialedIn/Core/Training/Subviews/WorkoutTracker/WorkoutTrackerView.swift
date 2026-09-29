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
    
    @State var presenter: WorkoutTrackerPresenter

    @ViewBuilder var exerciseTrackerView: (ExerciseTrackerDelegate, ((Int) -> Void)?) -> ExerciseTracker
    
    var body: some View {
        List {
            workoutOverviewCard
            exerciseSection
        }
        .navigationTitle(presenter.workoutSession.name)
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbarRole(.browser)
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
            LazyVGrid(columns: [GridItem(), GridItem(), GridItem()], spacing: 16) {
                VStack(alignment: .center, spacing: 4) {
                    Text("Current Workout")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(presenter.exercisesCount)
                        .font(.headline)
                }
                VStack(alignment: .center, spacing: 4) {
                    Text("Sets Completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(presenter.completedSetsFraction)
                        .font(.headline)
                        .foregroundColor(.green)
                }
                VStack(alignment: .center, spacing: 4) {
                    Text("Elapsed Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(presenter.workoutSession.dateCreated, style: .timer)
                        .font(.headline)
                }
                VStack(alignment: .center, spacing: 4) {
                    Text("Exercise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(presenter.exerciseFraction)
                        .font(.headline)
                }
                VStack(alignment: .center, spacing: 4) {
                    Text("Volume")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(presenter.formattedVolume)
                        .font(.headline)
                }
                VStack(alignment: .center, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text((presenter.workoutSession.notes ?? "").isEmpty ? String(localized: "None") : String(localized: "View"))
                        .font(.headline)
                }
                .onTapGesture {
                    presenter.presentWorkoutNotes()
                }
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
                    Image(systemName: "plus")
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
            VStack(alignment: .leading, spacing: 4) {
                Text("Rest Timer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let end = presenter.restEndTime,
                   now < end {
                    Text(timerInterval: now...end)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                } else {
                    Text((presenter.workoutSession.dateCreated), style: .timer)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
        }
        .padding(8)
        .padding(.horizontal, 8)
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
                    Label("Minimise Tracker", systemImage: "xmark")
                }

                Button {
                    presenter.onFinishPressed()
                } label: {
                    Label("Finish Workout", systemImage: "checkmark")
                }

                Button {
                    presenter.onWorkoutSettingsPressed()
                } label: {
                    Label("Workout Settings", systemImage: "dumbbell")
                }

                Button {
                    presenter.onGymProfilePressed()
                } label: {
                    Label("Gym Settings", systemImage: "building")
                }

                Button(role: .destructive) {
                    presenter.onDiscardWorkoutPressed()
                } label: {
                    Label("Delete Workout", systemImage: "trash")
                }
            } label: {
                Image(systemName: "line.3.horizontal")
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
