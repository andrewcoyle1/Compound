import SwiftUI

@Observable
@MainActor
class WarmupSetsPresenter {

    private let interactor: WarmupSetsInteractor
    private let router: WarmupSetsRouter

    var exercise: WorkoutExerciseModel

    init(interactor: WarmupSetsInteractor, router: WarmupSetsRouter, exercise: WorkoutExerciseModel) {
        self.interactor = interactor
        self.router = router
        self.exercise = exercise
    }
    
    func onViewAppear(delegate: WarmupSetsDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: WarmupSetsDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onDismissPressed() {
        router.dismissScreen()
    }
}

extension WarmupSetsPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: WarmupSetsDelegate)
        case onDisappear(delegate: WarmupSetsDelegate)

        var eventName: String {
            switch self {
            case .onAppear:                 return "WarmupSetsView_Appear"
            case .onDisappear:              return "WarmupSetsView_Disappear"
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
