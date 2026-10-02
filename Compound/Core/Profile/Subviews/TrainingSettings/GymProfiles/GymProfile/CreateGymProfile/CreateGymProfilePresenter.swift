import SwiftUI

@Observable
@MainActor
class CreateGymProfilePresenter {
    
    private let interactor: CreateGymProfileInteractor
    private let router: CreateGymProfileRouter
    
    var gymProfileName: String = ""
    
    var canSave: Bool { !gymProfileName.isEmpty }

    var userId: String? {
        interactor.userId
    }
    
    init(interactor: CreateGymProfileInteractor, router: CreateGymProfileRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: CreateGymProfileDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: CreateGymProfileDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onContinuePressed(oldDelegate: CreateGymProfileDelegate) {
        guard !gymProfileName.isEmpty,
              let userId
        else { return }
        
        let gymProfile = GymProfileModel(authorId: userId, name: gymProfileName)
        let delegate = GymProfileDelegate(onCompleted: {
            oldDelegate.onComplete?()
        }, gymProfile: gymProfile)
        router.showGymProfileView(delegate: delegate)
    }

}

extension CreateGymProfilePresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: CreateGymProfileDelegate)
        case onDisappear(delegate: CreateGymProfileDelegate)

        var eventName: String {
            switch self {
            case .onAppear:                 return "CreateGymProfileView_Appear"
            case .onDisappear:              return "CreateGymProfileView_Disappear"
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
