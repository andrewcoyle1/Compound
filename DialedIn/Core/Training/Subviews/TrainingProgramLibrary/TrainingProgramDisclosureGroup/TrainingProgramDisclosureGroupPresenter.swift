import SwiftUI

@Observable
@MainActor
class TrainingProgramDisclosureGroupPresenter {
    
    private let interactor: TrainingProgramDisclosureGroupInteractor
    private let router: TrainingProgramDisclosureGroupRouter
    
    init(interactor: TrainingProgramDisclosureGroupInteractor, router: TrainingProgramDisclosureGroupRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: TrainingProgramDisclosureGroupDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: TrainingProgramDisclosureGroupDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onSavedProgramPressed(_ program: TrainingProgram) {
        router.showEditTrainingProgramView(delegate: EditTrainingProgramDelegate(program: program))
    }

    func onSharePressed(_ program: TrainingProgram) {
        router.showShareToFollowerView(delegate: ShareToFollowerDelegate(payload: .program(program)))
    }

}

extension TrainingProgramDisclosureGroupPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: TrainingProgramDisclosureGroupDelegate)
        case onDisappear(delegate: TrainingProgramDisclosureGroupDelegate)

        var eventName: String {
            switch self {
            case .onAppear:                 return "TrainingProgramDisclosureGroupView_Appear"
            case .onDisappear:              return "TrainingProgramDisclosureGroupView_Disappear"
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
