import SwiftUI

@MainActor
protocol GymProfilesInteractor: GlobalInteractor {
    var userId: String? { get }
    var currentUser: UserModel? { get }
    var gymProfiles: [GymProfileModel] { get }
    func updateFavouriteGymProfileId(profileId: String?) async throws
    func deleteGymProfile(_ profileId: String) async throws
}

extension CoreInteractor: GymProfilesInteractor { }
