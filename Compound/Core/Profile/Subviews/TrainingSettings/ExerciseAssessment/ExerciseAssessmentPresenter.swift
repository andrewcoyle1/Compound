import SwiftUI

@Observable
@MainActor
class ExerciseAssessmentPresenter {
    
    private let interactor: ExerciseAssessmentInteractor
    private let router: ExerciseAssessmentRouter
    
    init(interactor: ExerciseAssessmentInteractor, router: ExerciseAssessmentRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: ExerciseAssessmentDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: ExerciseAssessmentDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
}

extension ExerciseAssessmentPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: ExerciseAssessmentDelegate)
        case onDisappear(delegate: ExerciseAssessmentDelegate)

        var eventName: String {
            switch self {
            case .onAppear:                 return "ExerciseAssessmentView_Appear"
            case .onDisappear:              return "ExerciseAssessmentView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
//            default:
//                return nil
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
