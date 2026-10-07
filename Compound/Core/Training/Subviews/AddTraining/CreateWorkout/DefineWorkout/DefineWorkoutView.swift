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

    /// The list's own edit mode: reordering and deleting, and the way into choosing a superset.
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            topSection
            exercisesSection
        }
        .onAppear {
            presenter.onViewAppear(autoOpensPicker: delegate.topSectionStyle == .standaloneWorkout)
        }
        .navigationTitle(delegate.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .environment(\.editMode, $editMode)
    }

    /// Reordering, and a visible way to delete, for a list that is otherwise swipe-only. While
    /// editing, Superset chooses exercises to run together, with its own Cancel and confirm.
    /// Trailing only, beside whatever the host puts in the bar.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if presenter.isSelectingSuperset {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Cancel") {
                    presenter.onSupersetCancelPressed()
                }
                .accessibilityIdentifier("DefineWorkout.cancelSuperset")
                Button("Superset") {
                    presenter.onSupersetConfirmPressed()
                }
                .fontWeight(.semibold)
                .disabled(!presenter.canConfirmSuperset)
                .accessibilityIdentifier("DefineWorkout.confirmSuperset")
            }
        } else if !presenter.exercises.isEmpty {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if editMode.isEditing, presenter.canStartSuperset {
                    Button("Superset") {
                        setEditing(false)
                        presenter.onSupersetPressed()
                    }
                    .accessibilityIdentifier("DefineWorkout.superset")
                }
                Button(editMode.isEditing ? "Done" : "Edit") {
                    setEditing(!editMode.isEditing)
                }
                .accessibilityIdentifier("DefineWorkout.edit")
            }
        }
    }

    private func setEditing(_ isEditing: Bool) {
        withReducedMotionAnimation(.standard) {
            editMode = isEditing ? .active : .inactive
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
                exerciseRow($exercise)
            }
            .onMove { presenter.moveExercises(from: $0, to: $1) }
            .onDelete { presenter.deleteExercises(at: $0) }
        } header: {
            if presenter.isSelectingSuperset {
                Text("Select two or more exercises")
            } else {
                exercisesHeader
            }
        }
    }

    private var exercisesHeader: some View {
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

    /// Choosing a superset, a tap ticks the row; otherwise it opens the exercise's targets and plan.
    @ViewBuilder
    private func exerciseRow(_ exercise: Binding<WorkoutTemplateExercise>) -> some View {
        let item = exercise.wrappedValue
        if presenter.isSelectingSuperset {
            rowContent(item)
                .anyButton(.highlight) {
                    presenter.onSupersetRowPressed(item)
                }
                .accessibilityAddTraits(presenter.isSelectedForSuperset(item) ? .isSelected : [])
                .accessibilityIdentifier("DefineWorkout.exercise.\(item.exercise.name)")
                .deleteDisabled(true)
                .moveDisabled(true)
        } else {
            rowContent(item)
                .anyButton(.highlight) {
                    presenter.onExercisePressed(exercise: exercise)
                }
                .rowActions(allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        presenter.removeExercise(exercise: item)
                    } label: {
                        Label("Delete", systemImage: Symbol.delete)
                    }
                    if item.supersetGroupId != nil {
                        Button {
                            presenter.onRemoveFromSupersetPressed(item)
                        } label: {
                            Label("Remove from superset", systemImage: Symbol.superset)
                        }
                    }
                }
                .accessibilityIdentifier("DefineWorkout.exercise.\(item.exercise.name)")
        }
    }

    private func rowContent(_ exercise: WorkoutTemplateExercise) -> some View {
        HStack(spacing: Spacing.m) {
            if presenter.isSelectingSuperset {
                // The selection glyph `ListRow` draws for a `.checkmark` row.
                let isSelected = presenter.isSelectedForSuperset(exercise)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .iconSize(.small)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                TemplateExerciseRow(exercise: exercise)
                planLine(exercise)
            }
        }
    }

    /// The superset's letter and the plan's parts, on one line under the exercise.
    @ViewBuilder
    private func planLine(_ exercise: WorkoutTemplateExercise) -> some View {
        let letter = presenter.supersetLetter(for: exercise)
        let summary = presenter.planSummary(for: exercise)
        if letter != nil || summary != nil {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                if let letter {
                    Chip(letter, systemImage: Symbol.superset, tint: .superset)
                        .accessibilityLabel(presenter.supersetAccessibilityLabel(letter: letter))
                }
                if let summary {
                    Text(summary)
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
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
