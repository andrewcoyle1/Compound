import SwiftUI

@Observable
@MainActor
class DefineWorkoutPresenter {
    
    private let interactor: DefineWorkoutInteractor
    private let router: DefineWorkoutRouter
    private var exercisesBinding: Binding<[WorkoutTemplateExercise]>
    
    /// Local observable mirror of `exercisesBinding` so SwiftUI refreshes when it changes.
    var exercises: [WorkoutTemplateExercise] = [] {
        didSet {
            if exercisesBinding.wrappedValue != exercises {
                exercisesBinding.wrappedValue = exercises
            }
        }
    }
    
    var currentUser: UserModel? {
        interactor.currentUser
    }
        
    var targetMuscleSummaries: [TargetMuscleSummary] {
        MuscleVolume.targetSummaries(exercises: exercises)
    }
    
    init(
        interactor: DefineWorkoutInteractor,
        router: DefineWorkoutRouter,
        exercises: Binding<[WorkoutTemplateExercise]>
    ) {
        self.interactor = interactor
        self.router = router
        self.exercisesBinding = exercises
        self.exercises = exercises.wrappedValue
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
    
    func onExercisePressed(exercise: Binding<WorkoutTemplateExercise>) {
        router.showSetTargetView(delegate: SetTargetDelegate(exercise: exercise))
    }
    
    func removeExercise(exercise: WorkoutTemplateExercise) {
        let index = exercises.firstIndex { exerciseItem in
            exercise.id == exerciseItem.id
        }
        guard let index else { return }
        
        exercises.remove(at: index)
    }
    
    func onAddExercisePressed() {
        router.showExercisesPickerView(
            delegate: ExercisesPickerDelegate(
                addedExercises: Binding(get: { self.exercises }, set: { newValue in
                    self.exercises = newValue
                })
            )
        )
    }
    
}

extension DefineWorkoutPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "DefineWorkoutView_Appear"
            case .onDisappear: return "DefineWorkoutView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }
}
