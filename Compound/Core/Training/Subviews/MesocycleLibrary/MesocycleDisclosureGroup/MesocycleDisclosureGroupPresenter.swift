import SwiftUI

@Observable
@MainActor
class MesocycleDisclosureGroupPresenter {
    
    private let interactor: MesocycleDisclosureGroupInteractor
    private let router: MesocycleDisclosureGroupRouter
    
    init(interactor: MesocycleDisclosureGroupInteractor, router: MesocycleDisclosureGroupRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: MesocycleDisclosureGroupDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: MesocycleDisclosureGroupDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onSavedMesocyclePressed(_ mesocycle: Mesocycle) {
        router.showEditMesocycleView(delegate: EditMesocycleDelegate(mesocycle: mesocycle))
    }

    func onSharePressed(_ mesocycle: Mesocycle) {
        router.showShareToFollowerView(delegate: ShareToFollowerDelegate(payload: .mesocycle(mesocycle)))
    }

}

extension MesocycleDisclosureGroupPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: MesocycleDisclosureGroupDelegate)
        case onDisappear(delegate: MesocycleDisclosureGroupDelegate)

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
