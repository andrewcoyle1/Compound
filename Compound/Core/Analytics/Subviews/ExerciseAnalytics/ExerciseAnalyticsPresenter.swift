import SwiftUI

@Observable
@MainActor
class ExerciseAnalyticsPresenter {

    private let interactor: ExerciseAnalyticsInteractor
    private let router: ExerciseAnalyticsRouter
    private let calendar = Calendar.current

    private(set) var exerciseCards: [ExerciseCardItem] = []

    var workoutSessions: [WorkoutSessionModel] {
        interactor.workoutSessions
    }
    
    var systemExercises: [ExerciseModel] {
        interactor.systemExercises
    }
    
    var userExercises: [ExerciseModel] {
        interactor.userExercises
    }
    
    init(interactor: ExerciseAnalyticsInteractor, router: ExerciseAnalyticsRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func loadData() async {
        let completed = workoutSessions.filter { $0.endedAt != nil }
        let aggregated = ExerciseOneRMAggregator.aggregate(sessions: completed)
        
        var seenIds = Set<String>()
        let combined: [ExerciseModel] = userExercises + systemExercises
        let allExercises: [ExerciseModel] = combined
            .filter { (template: ExerciseModel) in
                seenIds.insert(template.id).inserted
            }
            .sorted { (lhs: ExerciseModel, rhs: ExerciseModel) in
                lhs.name.localizedCompare(rhs.name) == .orderedAscending
            }
        
        self.exerciseCards = allExercises.map { (exercise: ExerciseModel) -> ExerciseCardItem in
            let data = aggregated[exercise.id]
            let unit = interactor.getPreference(templateId: exercise.id).weightUnit
            let sparkline: [(date: Date, value: Double)] = (data?.last7Workouts ?? []).map {
                (date: $0.date, value: UnitConversion.convertWeight($0.value, to: unit))
            }
            return ExerciseCardItem(
                templateId: exercise.id,
                name: exercise.name,
                sparklineData: sparkline,
                latest1RM: UnitConversion.convertWeight(data?.latest1RM ?? 0, to: unit),
                unitText: unit.abbreviation
            )
        }
    }

    func onExercisePressed(templateId: String, name: String, themeColor: Color?) {
        router.showExerciseDetailView(templateId: templateId, name: name, delegate: ExerciseDetailDelegate(), themeColor: themeColor)
    }

    func onDismissPressed() {
        router.dismissScreen()
    }
}

extension ExerciseAnalyticsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear:             return "ExerciseAnalyticsView_Appear"
            case .onDisappear:          return "ExerciseAnalyticsView_Disappear"
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
