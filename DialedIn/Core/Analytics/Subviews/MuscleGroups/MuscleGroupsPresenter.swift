import SwiftUI

@Observable
@MainActor
class MuscleGroupsPresenter {

    private let interactor: MuscleGroupsInteractor
    private let router: MuscleGroupsRouter
    private let calendar = Calendar.current

    private(set) var muscleSetsData: [Muscles: (last7Days: [Double], total: Double)] = [:]

    var upperMuscles: [Muscles] {
        Muscles.allCases.filter { $0.bodyRegion == .upperBody }
    }

    var lowerMuscles: [Muscles] {
        Muscles.allCases.filter { $0.bodyRegion == .lowerBody }
    }
    
    var workoutSessions: [WorkoutSessionModel] {
        interactor.workoutSessions
    }
    
    var allExercises: [ExerciseModel] {
        interactor.allExercises
    }

    init(interactor: MuscleGroupsInteractor, router: MuscleGroupsRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func loadData() {

        let completed = workoutSessions.filter { $0.endedAt != nil }
        
        let templateIds = Set(completed.flatMap { $0.exercises.map(\.templateId) })
        let templates: [String: ExerciseModel]
        if templateIds.isEmpty {
            templates = [:]
        } else {
            templates = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })
        }
        
        muscleSetsData = MuscleGroupSetsAggregator.aggregate(
            sessions: completed,
            templates: templates,
            calendar: calendar
        )
    }

    func setsData(for muscle: Muscles) -> (last7Days: [Double], total: Double) {
        muscleSetsData[muscle] ?? (Array(repeating: 0, count: 7).map(Double.init), 0.0)
    }

    func onMusclePressed(muscle: Muscles, themeColor: Color?) {
        router.showMuscleGroupDetailView(muscle: muscle, delegate: MuscleGroupDetailDelegate(), themeColor: themeColor)
    }

    func onMuscleBalancePressed() {
        router.showMuscleBalanceView()
    }

    func onDismissPressed() {
        router.dismissScreen()
    }
}

extension MuscleGroupsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear:    return "MuscleGroupsView_Appear"
            case .onDisappear: return "MuscleGroupsView_Disappear"
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
