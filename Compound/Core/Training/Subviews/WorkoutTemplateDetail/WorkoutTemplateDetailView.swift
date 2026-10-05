//
//  WorkoutTemplateDetailView.swift
//  Compound
//
//  Created by Andrew Coyle on 23/09/2025.
//

import SwiftUI

struct WorkoutTemplateDetailDelegate {
    let workoutTemplate: WorkoutTemplateModel
    let mesocycleId: String?
    let onStartWorkoutPressed: (@Sendable () -> Void)?
    var isDeloadCycle: Bool = false
    var periodisationPhase: PeriodisationPhase?
    /// False for a preview of a later microcycle's day, which is not started from there.
    var allowsStart: Bool = true
    /// The mesocycle this workout is a day of, when the library opens one to start on its own
    /// (so `mesocycleId` is nil). Opened from the mesocycle itself, `mesocycleId` says the same.
    var mesocycle: Mesocycle?
}

struct WorkoutTemplateDetailView: View {

    @State var presenter: WorkoutTemplateDetailPresenter
    
    let delegate: WorkoutTemplateDetailDelegate

    private var isAuthor: Bool {
        presenter.currentUser?.userId == delegate.workoutTemplate.authorId
    }

    private var owningMesocycle: Mesocycle? {
        presenter.owningMesocycle(delegate: delegate)
    }
    
    var body: some View {
        List {
            targetMusclesSection
            exercisesSection
        }
        .navigationTitle(delegate.workoutTemplate.name)
        .navigationSubtitle(delegate.workoutTemplate.description ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .toolbar {
            toolbarContent
        }
        .onAppear { presenter.onViewAppear(delegate: delegate) }
        .onDisappear { presenter.onViewDisappear(delegate: delegate) }
        .bottomCTA {
            if delegate.allowsStart {
                CallToActionButton(isLoading: presenter.isStarting) {
                    presenter.onStartWorkoutPressed(
                        onStartWorkout: delegate.onStartWorkoutPressed,
                        workoutTemplate: delegate.workoutTemplate,
                        mesocycleId: delegate.mesocycleId,
                        isDeloadCycle: delegate.isDeloadCycle
                    )
                } label: {
                    Text("Start Workout")
                }
                .disabled(presenter.isStarting)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if let mesocycle = owningMesocycle {
            // A day lives in its mesocycle, not the library: it is changed there, and kept apart
            // from it only as a copy the user asks for.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        presenter.onEditMesocyclePressed(mesocycle)
                    } label: {
                        Label("Edit Mesocycle", systemImage: Symbol.edit)
                    }
                    Button {
                        presenter.onSaveCopyPressed(template: delegate.workoutTemplate)
                    } label: {
                        Label("Save a Copy to Workouts", systemImage: Symbol.add)
                    }
                    Button {
                        presenter.onSharePressed(template: delegate.workoutTemplate)
                    } label: {
                        Label("Share with Friends", systemImage: Symbol.share)
                    }
                } label: {
                    Image(systemName: Symbol.more)
                }
                .accessibilityLabel("Workout options")
            }
        } else if isAuthor {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        presenter.onEditWorkoutPressed(template: delegate.workoutTemplate)
                    } label: {
                        Label("Edit Workout", systemImage: Symbol.edit)
                    }
                    Button {
                        presenter.onSharePressed(template: delegate.workoutTemplate)
                    } label: {
                        Label("Share with Friends", systemImage: Symbol.share)
                    }
                    Button(role: .destructive) {
                        presenter.showDeleteConfirmation(workoutTemplate: delegate.workoutTemplate)
                    } label: {
                        Label("Delete Workout", systemImage: Symbol.delete)
                    }
                } label: {
                    Image(systemName: Symbol.more)
                }
                .disabled(presenter.isDeleting)
                .accessibilityLabel("Workout options")
            }
        }

    }
    
    private var targetMusclesSection: some View {
        TargetMusclesSection(summaries: presenter.targetMuscleSummaries(exercises: delegate.workoutTemplate.exercises))
    }

    private var exercisesSection: some View {
        Section {
            ForEach(delegate.workoutTemplate.exercises) { exercise in
                TemplateExerciseRow(exercise: exercise)
                    .anyButton(.highlight) {
                        presenter.onExercisePressed(exercise.exercise)
                    }
            }
        } header: {
            // The "+" here had its action commented out. Authors add exercises through Edit
            // Workout in the toolbar menu; nobody else can change the template.
            Text("^[\(delegate.workoutTemplate.exercises.count) Exercise](inflect: true)")
        }
    }

}

extension CoreBuilder {
    func workoutTemplateDetailView(router: AnyRouter, delegate: WorkoutTemplateDetailDelegate) -> some View {
        WorkoutTemplateDetailView(
            presenter: WorkoutTemplateDetailPresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                )
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate) {
        router.showScreen(.push) { router in
            builder.workoutTemplateDetailView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.workoutTemplateDetailView(
            router: router,
            delegate: WorkoutTemplateDetailDelegate(
                workoutTemplate: WorkoutTemplateModel.mock,
                mesocycleId: nil,
                onStartWorkoutPressed: {
                    
                }
            )
        )
    }
    
}
