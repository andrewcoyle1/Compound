import SwiftUI

@MainActor
protocol ScaleWeightInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var bodyMeasurements: [BodyMeasurementEntry] { get }
    func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws
    func syncWeightFromHealthKit() async
}

extension CoreInteractor: ScaleWeightInteractor { }
