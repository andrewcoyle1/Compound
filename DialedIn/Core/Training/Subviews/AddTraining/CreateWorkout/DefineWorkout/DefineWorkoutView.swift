import Foundation
import SwiftUI

enum DefineWorkoutTopSectionStyle: Hashable {
    /// Standalone workout creation flow (via `DefineWorkoutWrapperView`).
    /// Always shows the target-muscles summary section.
    case standaloneWorkout
    
    /// Program design flow. If the day has no exercises, show the "Rest Day" header section.
    /// Otherwise, show target-muscles summary.
    case programDay
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
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private var topSection: some View {
        if delegate.topSectionStyle == .programDay, presenter.exercises.isEmpty {
            restDaySection
        } else {
            targetMusclesSection
        }
    }
    
    private var restDaySection: some View {
        Section {
            HStack {
                Image(systemName: "sun.max")
                Text("You can convert the rest day into a workout day by add exercises below")
            }
            .frame(maxWidth: .infinity)
        } header: {
            Text("Rest Day")
        }
    }
    
    private var targetMusclesSection: some View {
        Section {
            if presenter.targetMuscleSummaries.isEmpty {
                HStack {
                    Image(systemName: "figure.wave")
                        .font(.system(size: 32))
                        .frame(width: 40)
                    Text("You haven't added any exercises yet. Once you add an exercise, target muscles will appear here.")
                }
            } else {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(presenter.targetMuscleSummaries) { summary in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(summary.muscle.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                
                                Text("\(formattedSetCount(summary.weightedTargetSets)) target sets")
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
    
    private func formattedSetCount(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(rounded - value) < 0.000_01 {
            return "\(Int(rounded))"
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    private var exercisesSection: some View {
        Section {
            ForEach($presenter.exercises) { $exercise in
                HStack {
                    ImageLoaderView(urlString: exercise.exercise.imageURL ?? Constants.randomImage)
                        .frame(width: 60, height: 60)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.exercise.name)
                            .fontWeight(.semibold)
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
                                    Text(key.name)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .padding(4)
                                        .padding(.horizontal, 4)
                                        .background(value == .secondary ? Color.secondary.opacity(0.2) : Color.secondary.opacity(0.4), in: Capsule())
                                }
                            }
                        }
                    }
                }
                .anyButton(.highlight) {
                    presenter.onExercisePressed(exercise: $exercise)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        presenter.removeExercise(exercise: exercise)
                    }
                }
            }
        } header: {
            HStack {
                VStack {
                    Text("\(presenter.exercises.count) Exercises")
                }
                Spacer()
                Button {
                    presenter.onAddExercisePressed()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add exercise")
                .accessibilityIdentifier("DefineWorkout.addExercise")
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
        
        return HStack {
            Circle()
                .frame(width: 12, height: 12)
                .foregroundStyle(.secondary)
                .overlay {
                    Text("\(target.setNumber)")
                }
            Text(descriptionString)
        }
        .font(.caption)
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
