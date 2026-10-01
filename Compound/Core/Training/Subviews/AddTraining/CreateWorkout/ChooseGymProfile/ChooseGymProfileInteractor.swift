import SwiftUI

@MainActor
protocol ChooseGymProfileInteractor: GlobalInteractor {
    var userId: String? { get }
    var currentUser: UserModel? { get }
    var favouriteGymProfile: GymProfileModel? { get }
    var gymProfiles: [GymProfileModel] { get }
    func deleteGymProfile(_ profileId: String) async throws
}

extension CoreInteractor: ChooseGymProfileInteractor { }
