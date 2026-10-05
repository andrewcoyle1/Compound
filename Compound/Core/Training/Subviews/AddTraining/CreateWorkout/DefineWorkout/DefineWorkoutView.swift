import Foundation
import SwiftUI

enum DefineWorkoutTopSectionStyle: Hashable {
    /// Standalone workout creation flow (via `DefineWorkoutWrapperView`).
    /// Always shows the target-muscles summary section.
    case standaloneWorkout
    
    /// Mesocycle design flow. If the day has no exercises, show the "Rest Day" header section.
    /// Otherwise, show target-muscles summary.
    case mesocycleDay
}

struct DefineWorkoutDelegate {
    let name: String
    let gymProfile: GymProfileModel
    var exercises: Binding<[WorkoutTemplateExercise]>
    var topSectionStyle: DefineWorkoutTopSectionStyle = .standaloneWorkout
}

struct DefineWorkoutView: View {
    
    @State var presenter: DefineWorkoutPresenter
    let delegate: DefineWorkoutDelegate
    
    var body: some View {
        List {
            topSection
            exercisesSection
        }
        .onAppear {
            presenter.onViewAppear(autoOpensPicker: delegate.topSectionStyle == .standaloneWorkout)
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .navigationTitle(delegate.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Reordering, and a visible way to delete, for a list that is otherwise swipe-only.
            if !presenter.exercises.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    @ViewBuilder
    private var topSection: some View {
        if delegate.topSectionStyle == .mesocycleDay, presenter.exercises.isEmpty {
            restDaySection
        } else {
            targetMusclesSection
        }
    }
    
    private var restDaySection: some View {
        Section("Rest Day") {
            ListRow(
                title: String(localized: "Add exercises to turn this rest day into a workout day."),
                systemImage: Symbol.restDay,
                tint: .secondary
            )
        }
    }
    
    private var targetMusclesSection: some View {
        TargetMusclesSection(summaries: presenter.targetMuscleSummaries)
    }

    private var exercisesSection: some View {
        Section {
            ForEach($presenter.exercises) { $exercise in
                TemplateExerciseRow(exercise: exercise)
                    .anyButton(.highlight) {
                        presenter.onExercisePressed(exercise: $exercise)
                    }
                    .rowActions(allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            presenter.removeExercise(exercise: exercise)
                        } label: {
                            Label("Delete", systemImage: Symbol.delete)
                        }
                    }
            }
            .onMove { presenter.moveExercises(from: $0, to: $1) }
            .onDelete { presenter.deleteExercises(at: $0) }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("^[\(presenter.exercises.count) Exercise](inflect: true)")
                Spacer()
                Button {
                    presenter.onAddExercisePressed()
                } label: {
                    Image(systemName: Symbol.add)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Add exercise")
                .accessibilityIdentifier("DefineWorkout.addExercise")
            }
        }
    }
}

extension CoreBuilder {
    
    func defineWorkoutView(router: AnyRouter, delegate: DefineWorkoutDelegate) -> some View {
        DefineWorkoutView(
            presenter: DefineWorkoutPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                exercises: delegate.exercises
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showDefineWorkoutView(delegate: DefineWorkoutDelegate) {
        router.showScreen(.push) { router in
            builder.defineWorkoutView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    @Previewable @State var exercises: [WorkoutTemplateExercise] = WorkoutTemplateExercise.mocks
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = DefineWorkoutDelegate(
        name: "Sample Workout",
        gymProfile: GymProfileModel.mock,
        exercises: $exercises,
        topSectionStyle: .standaloneWorkout
    )
    
    return RouterView { router in
        builder.defineWorkoutView(router: router, delegate: delegate)
    }
    
}
