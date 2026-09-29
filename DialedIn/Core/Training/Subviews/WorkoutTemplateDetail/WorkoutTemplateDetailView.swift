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
        .safeAreaInset(edge: .bottom) {
            CallToActionButton(isPrimaryAction: true) {
                presenter.onStartWorkoutPressed(
                    onStartWorkout: delegate.onStartWorkoutPressed,
                    workoutTemplate: delegate.workoutTemplate,
                    trainingProgramId: delegate.trainingProgramId,
                    isDeloadCycle: delegate.isDeloadCycle
                )
            } label: {
                Text("Start Workout")
            }
            .padding(.bottom)
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
                        Label("Edit Workout", systemImage: "pencil")
                    }
                    Button {
                        presenter.onSharePressed(template: delegate.workoutTemplate)
                    } label: {
                        Label("Share with Friends", systemImage: "paperplane")
                    }
                    Button(role: .destructive) {
                        presenter.showDeleteConfirmation(workoutTemplate: delegate.workoutTemplate)
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .disabled(presenter.isDeleting)
                .accessibilityLabel("Workout options")
            }
        }

        #if DEBUG || MOCK
        ToolbarItem(placement: .topBarLeading) {
            Button {
                presenter.onDevSettingsPressed()
            } label: {
                Image(systemName: "info")
            }
            .accessibilityLabel("Developer settings")
        }
        #endif
    }
    
    private var targetMusclesSection: some View {
        Section {
            if presenter.targetMuscleSummaries(exercises: delegate.workoutTemplate.exercises).isEmpty {
                HStack {
                    Image(systemName: "figure.wave")
                        .font(.system(size: 32))
                        .frame(width: 40)
                    Text("You haven't added any exercises yet. Once you add an exercise, target muscles will appear here.")
                }
            } else {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(presenter.targetMuscleSummaries(exercises: delegate.workoutTemplate.exercises)) { summary in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(summary.muscle.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                
                                Text("\(presenter.formattedSetCount(summary.weightedTargetSets)) target sets")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                
                                Text("\(summary.exerciseCount) \(summary.exerciseCount == 1 ? String(localized: "exercise") : String(localized: "exercises"))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(10)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .removeListRowFormatting()
                .scrollIndicators(.hidden)
            }
        } header: {
            Text("Target Muscles")
        }
    }
    
    private var exercisesSection: some View {
        Section {
            ForEach(delegate.workoutTemplate.exercises) { exercise in
                // The image goes above the details at accessibility sizes; beside them it left the
                // name a few letters before the ellipsis.
                AdaptiveStack {
                    ImageLoaderView(urlString: exercise.exercise.imageURL ?? Constants.randomImage, resizingMode: .fit)
                        .frame(width: 60, height: 60)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.exercise.name)
                            .fontWeight(.semibold)
                            .fixedSize(horizontal: false, vertical: true)
                        LazyHGrid(rows: [GridItem(), GridItem()]) {
                            ForEach(exercise.setTargets) { target in
                                setTarget(target)
                            }
                        }
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(
                                    exercise.exercise.muscleGroups.sorted { $0.key.name < $1.key.name },
                                    id: \.key
                                ) { key, value in
                                    // Primary muscles were told from secondary by a darker fill
                                    // alone; the weight and the label say it without colour.
                                    Text(key.name)
                                        .font(.caption2)
                                        .fontWeight(value == .secondary ? .regular : .semibold)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .accessibilityLabel("\(key.name), \(value == .secondary ? String(localized: "secondary") : String(localized: "primary"))")
                                        .padding(4)
                                        .padding(.horizontal, 4)
                                        .background(value == .secondary ? Color.secondary.opacity(0.2) : Color.secondary.opacity(0.4), in: Capsule())
                                }
                            }
                        }
                    }
                }
                .anyButton(.highlight) {
                    presenter.onExercisePressed(exercise.exercise)
                }
            }
        } header: {
            HStack {
                VStack {
                    Text("\(delegate.workoutTemplate.exercises.count) Exercises")
                }
                Spacer()
                Button {
//                    presenter.onAddExercisePressed()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add exercise")
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func setTarget(_ target: SetTarget) -> some View {
        
        var descriptionString: String = "No target set"
        if let maxReps = target.maxReps {
            if let minReps = target.minReps {
                descriptionString = "\(minReps)-\(maxReps) reps"
            } else {
                descriptionString = "1-\(maxReps) reps"
            }
        } else if let minReps = target.minReps,
                  target.maxReps == nil {
            descriptionString = "\(minReps)+ reps"
        }
           
        // The number sizes its own badge: a fixed 12pt circle drew over the text beside it once
        // the number outgrew it.
        return HStack {
            Text("\(target.setNumber)")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: .capsule)
            Text(descriptionString)
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Set \(target.setNumber), \(descriptionString)")
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
