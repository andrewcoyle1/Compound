import SwiftUI

@Observable
@MainActor
class MuscleGroupPickerPresenter {
    
    private let interactor: MuscleGroupPickerInteractor
    private let router: MuscleGroupPickerRouter
    
    var selectedMuscleGroups: [Muscles: MuscleTargetType] = [:]
    
    init(interactor: MuscleGroupPickerInteractor, router: MuscleGroupPickerRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    var upperMuscles: [Muscles] {
        Muscles.allCases.filter { $0.bodyRegion == .upperBody }
    }

    var lowerMuscles: [Muscles] {
        Muscles.allCases.filter { $0.bodyRegion == .lowerBody }
    }

    var primaryCount: Int {
        selectedMuscleGroups.values.filter { $0 == .primary }.count
    }

    var secondaryCount: Int {
        selectedMuscleGroups.values.filter { $0 == .secondary }.count
    }

    func onMuscleGroupPressed(muscle: Muscles) {
        switch selectedMuscleGroups[muscle] {
        case nil:        selectedMuscleGroups[muscle] = .primary
        case .primary:   selectedMuscleGroups[muscle] = .secondary
        case .secondary: selectedMuscleGroups.removeValue(forKey: muscle)
        }
        interactor.playHaptic(option: .selection)
    }
    
    func onNextPressed(delegate: MuscleGroupPickerDelegate) {
        let newDelegate = ExerciseEquipmentDelegate(
            name: delegate.name,
            trackableMetricA: delegate.trackableMetricA,
            trackableMetricB: delegate.trackableMetricB,
            exerciseType: delegate.exerciseType,
            laterality: delegate.laterality,
            muscleGroups: selectedMuscleGroups
        )

        router.showExerciseEquipmentView(delegate: newDelegate)
    }
    
    func onResetPressed() {
        selectedMuscleGroups = [:]
    }
    
}

extension MuscleGroupPickerPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "MuscleGroupPickerView_Appear"
            case .onDisappear: return "MuscleGroupPickerView_Disappear"
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
