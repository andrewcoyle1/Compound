import SwiftUI

@MainActor
protocol GymProfileInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    func saveGymProfile(profile: GymProfileModel, image: PlatformImage?) async throws
    func updateFavouriteGymProfileId(profileId: String?) async throws

}

extension CoreInteractor: GymProfileInteractor { }
