import SwiftUI

@Observable
@MainActor
class GymProfilesPresenter {
    
    private let interactor: GymProfilesInteractor
    private let router: GymProfilesRouter
    
    var currentUser: UserModel? {
        interactor.currentUser
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
    
    var favouriteGymProfile: GymProfileModel? {
        gymProfiles.first(where: { $0.id == favouriteGymProfileId })
    }
    
    var nonFavouriteGymProfiles: [GymProfileModel] {
        gymProfiles.filter { $0.id != favouriteGymProfileId }
    }
    
    init(interactor: GymProfilesInteractor, router: GymProfilesRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
    
    func onAddGymProfilePressed() {
        guard let userId = interactor.userId else { return }
        let delegate = GymProfileDelegate(gymProfile: GymProfileModel(authorId: userId))
        router.showGymProfileView(delegate: delegate)
    }

    func onGymProfilePressed(gymProfile: GymProfileModel) {
        let delegate = GymProfileDelegate(gymProfile: gymProfile)
        router.showGymProfileView(delegate: delegate)
    }
        
    func deleteGymProfile(profile: GymProfileModel) {
        Task {
            interactor.trackEvent(event: Event.deleteProfileStart)
            do {
                try await interactor.deleteGymProfile(profile.id)
                interactor.trackEvent(event: Event.deleteProfileSuccess)
            } catch {
                interactor.trackEvent(event: Event.deleteProfileFail(error: error))
                // The row is still in the list afterwards, so without this the swipe just looks
                // like it did not take.
                router.showSimpleAlert(title: String(localized: "Unable to delete gym profile"), subtitle: String(localized: "Please try again."))
            }
        }
    }
    
    func favouriteGymProfile(profile: GymProfileModel) {
        Task {
            interactor.trackEvent(event: Event.favouriteGymProfileStart)

            do {
                try await interactor.updateFavouriteGymProfileId(profileId: profile.id)
                interactor.trackEvent(event: Event.favouriteGymProfileSuccess)

            } catch {
                interactor.trackEvent(event: Event.favouriteGymProfileFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to set your usual gym"), subtitle: String(localized: "Please try again."))
            }
        }
    }
    
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case deleteProfileStart
        case deleteProfileSuccess
        case deleteProfileFail(error: Error)
        case favouriteGymProfileStart
        case favouriteGymProfileSuccess
        case favouriteGymProfileFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:                     return "GymProfilesView_Appear"
            case .onDisappear:                  return "GymProfilesView_Disappear"
            case .deleteProfileStart:           return "GymProfilesView_DeleteProfile_Start"
            case .deleteProfileSuccess:         return "GymProfilesView_DeleteProfile_Success"
            case .deleteProfileFail:            return "GymProfilesView_DeleteProfile_Fail"
            case .favouriteGymProfileStart:     return "GymProfilesView_FavouriteGymProfile_Start"
            case .favouriteGymProfileSuccess:   return "GymProfilesView_FavouriteGymProfile_Success"
            case .favouriteGymProfileFail:      return "GymProfilesView_FavouriteGymProfile_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .deleteProfileFail(error: let error),
                    .favouriteGymProfileFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .deleteProfileFail, .favouriteGymProfileFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
