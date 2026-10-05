import SwiftUI

@Observable
@MainActor
class CreateMesocyclePresenter {
    
    private let interactor: CreateMesocycleInteractor
    private let router: CreateMesocycleRouter
    
    init(interactor: CreateMesocycleInteractor, router: CreateMesocycleRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    /// The program matched to how often the user said they exercise, shown first. Nil when they
    /// have not said, or it is not one of the shipped programs.
    var recommendedProgram: Mesocycle? {
        guard let id = Self.recommendedProgramId(for: interactor.currentUser?.submittedExerciseFrequency) else { return nil }
        return interactor.prebuiltMesocycles.first { $0.id == id }
    }

    /// Every other shipped program, fewest workouts a week first.
    var otherPrograms: [Mesocycle] {
        interactor.prebuiltMesocycles
            .filter { $0.id != recommendedProgram?.id }
            .sorted { (workoutsPerMicrocycle(of: $0), $0.name) < (workoutsPerMicrocycle(of: $1), $1.name) }
    }

    /// Two or fewer sessions a week, or none yet, start on full body; three or four on an upper and
    /// lower split; five or more on push/pull/legs. 5/3/1 is never the suggestion: it asks for
    /// experience a first program cannot assume.
    static func recommendedProgramId(for frequency: ExerciseFrequency?) -> String? {
        switch frequency {
        case .never, .oneToTwo: return "program-full-body"
        case .threeToFour: return "program-upper-lower"
        case .fiveToSix, .daily: return "program-push-pull-legs"
        case nil: return nil
        }
    }

    func workoutsPerMicrocycle(of mesocycle: Mesocycle) -> Int {
        mesocycle.workoutTemplates.filter { !$0.exercises.isEmpty }.count
    }

    /// "3 workouts a week · 8 weeks" for a seven-day microcycle, which all four programs are.
    func summary(of mesocycle: Mesocycle) -> String {
        let workouts = String(localized: "\(workoutsPerMicrocycle(of: mesocycle)) workouts")
        guard mesocycle.workoutTemplates.count == 7 else {
            let days = String(localized: "\(mesocycle.workoutTemplates.count) days")
            return String(localized: "\(workouts) every \(days)")
        }
        let weeks = String(localized: "\(mesocycle.numMicrocycles) weeks")
        return String(localized: "\(workouts) a week · \(weeks)")
    }

    /// Previews the program, whose Start resumes onboarding once it is the active mesocycle.
    func onProgramPressed(_ mesocycle: Mesocycle, delegate: CreateMesocycleDelegate) {
        interactor.trackEvent(event: Event.programPressed(mesocycleId: mesocycle.id, isRecommended: mesocycle.id == recommendedProgram?.id))
        router.showPrebuiltMesocycleDetailView(mesocycle: mesocycle, onStarted: delegate.onComplete)
    }

    /// Build My Own: the name, icon and design steps, as before.
    func onNextPressed(delegate: CreateMesocycleDelegate) {
        interactor.trackEvent(event: Event.buildOwnPressed)
        router.showNameMesocycleView(delegate: NameMesocycleDelegate(onComplete: delegate.onComplete))
    }
}

extension CreateMesocyclePresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case programPressed(mesocycleId: String, isRecommended: Bool)
        case buildOwnPressed
        
        var eventName: String {
            switch self {
            case .onAppear: return "CreateProgramView_Appear"
            case .onDisappear: return "CreateProgramView_Disappear"
            case .programPressed: return "CreateProgramView_Program_Pressed"
            case .buildOwnPressed: return "CreateProgramView_BuildOwn_Pressed"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .programPressed(let mesocycleId, let isRecommended):
                return ["program_id": mesocycleId, "is_recommended": isRecommended]
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
