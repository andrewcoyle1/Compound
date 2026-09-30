//
//  WorkoutTemplateDetailView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 23/09/2025.
//

import SwiftUI

struct WorkoutTemplateDetailDelegate {
    let workoutTemplate: WorkoutTemplateModel
    let trainingProgramId: String?
    let onStartWorkoutPressed: (@Sendable () -> Void)?
    var isDeloadCycle: Bool = false
    var periodisationPhase: PeriodisationPhase?
}

struct WorkoutTemplateDetailView: View {

    @State var presenter: WorkoutTemplateDetailPresenter
    
    let delegate: WorkoutTemplateDetailDelegate

    private var isAuthor: Bool {
        presenter.currentUser?.userId == delegate.workoutTemplate.authorId
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
        .bottomCTA {
            CallToActionButton(isLoading: presenter.isStarting) {
                presenter.onStartWorkoutPressed(
                    onStartWorkout: delegate.onStartWorkoutPressed,
                    workoutTemplate: delegate.workoutTemplate,
                    trainingProgramId: delegate.trainingProgramId,
                    isDeloadCycle: delegate.isDeloadCycle
                )
            } label: {
                Text("Start Workout")
            }
            .disabled(presenter.isStarting)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isAuthor {
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
                trainingProgramId: nil,
                onStartWorkoutPressed: {
                    
                }
            )
        )
    }
    
}
