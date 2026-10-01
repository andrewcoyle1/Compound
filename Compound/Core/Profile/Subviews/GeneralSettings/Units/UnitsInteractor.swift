import SwiftUI

@MainActor
protocol UnitsInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    func updateUnitPreferences(
        length: LengthUnitPreference,
        weight: WeightUnitPreference,
        distance: DistanceUnitPreference
    ) async throws
}

extension CoreInteractor: UnitsInteractor { }
