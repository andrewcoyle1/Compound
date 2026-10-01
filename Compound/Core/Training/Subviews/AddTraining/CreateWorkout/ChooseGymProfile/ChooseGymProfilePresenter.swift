import SwiftUI

@Observable
@MainActor
class ChooseGymProfilePresenter {
    
    private let interactor: ChooseGymProfileInteractor
    private let router: ChooseGymProfileRouter
    
    var favouriteGymProfile: GymProfileModel? {
        interactor.favouriteGymProfile
    }
    
    var gymProfiles: [GymProfileModel] {
        interactor.gymProfiles
    }
    
    var numGyms: Int {
        gymProfiles.count
    }
    
    var favouriteGymProfileId: String? {
        interactor.currentUser?.submittedFavouriteGymProfileId
    }

    init(interactor: ChooseGymProfileInteractor, router: ChooseGymProfileRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onGymProfilePressed(name: String, profile: GymProfileModel, delegate: ChooseGymProfileDelegate) {
        router.showDefineWorkoutWrapperView(
            delegate: DefineWorkoutWrapperDelegate(
                name: name,
                gymProfile: profile,
                workoutTemplate: delegate.workoutTemplate,
                draftExercises: delegate.draftExercises
            )
        )
    }
    
    func onCreateGymProfilePressed() {
        router.showCreateGymProfileView(delegate: CreateGymProfileDelegate())
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear:     return "ChooseGymProfileView_Appear"
            case .onDisappear:  return "ChooseGymProfileView_Disappear"
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
