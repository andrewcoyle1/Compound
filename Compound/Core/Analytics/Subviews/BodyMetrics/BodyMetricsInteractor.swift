import SwiftUI

@MainActor
protocol BodyMetricsInteractor: GlobalInteractor {
    func backfillBodyFatFromHealthKit() async
    var bodyMeasurements: [BodyMeasurementEntry] { get }
    /// For waist-to-height, whose denominator is the profile's height rather than a measurement.
    var currentUser: UserModel? { get }
    func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws
    func uploadImage(image: PlatformImage, path: String) async throws -> URL
    func deleteImage(path: String) async throws
}

extension CoreInteractor: BodyMetricsInteractor { }

extension BodyMetricsInteractor {

    /// The unit body measurements are shown in. Circumferences are stored in centimetres — see
    /// `LogMeasurementPresenter.measurementCm` — and sixteen of the eighteen detail screens
    /// printed those centimetres under a hardcoded " in" suffix.
    var lengthUnitPreference: LengthUnitPreference {
        currentUser?.submittedLengthUnitPreference ?? .centimeters
    }
}
