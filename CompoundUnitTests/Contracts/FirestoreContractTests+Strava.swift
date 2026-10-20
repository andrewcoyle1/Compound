//
//  FirestoreContractTests+Strava.swift
//  CompoundUnitTests
//
//  Activities imported from Strava (`users/{uid}/strava_activities/{id}`) under the Firestore
//  contract. Only the server writes them (`stravaActivityDoc` in functions/lib.js, at connect and
//  from the webhook); both apps read them, on the owner's own screens only. The contract holds the
//  function's shape to what Swift and Dart decode. See FirestoreContractTests.swift.
//

import Foundation
import Testing
import FirebaseFirestore
@testable import Compound

extension FirestoreContractTests {

    /// Every field: `stravaActivityDoc` writes the whole document by name. The app never writes or
    /// queries one by name.
    static func stravaContracts() throws -> [Contract] {
        [
            try contract(
                StravaImportedActivity.self, directory: "strava_imported_activity",
                full: Samples.fullStravaActivity, minimal: Samples.minimalStravaActivity,
                namedFields: []
            )
        ]
    }
}

extension Samples {
    static let fullStravaActivity = StravaImportedActivity(
        id: "12345678901",
        name: "Morning Run",
        sportType: "Run",
        startDate: date("2026-10-11T06:30:00.000Z"),
        elapsedTime: 2_100,
        movingTime: 1_980,
        distance: 6_200.5,
        totalElevationGain: 45.5,
        averageHeartrate: 151.25
    )

    static let minimalStravaActivity = StravaImportedActivity(
        id: "12345678902",
        name: "Evening Ride",
        sportType: "Ride",
        startDate: date("2026-10-09T17:45:12.500Z"),
        elapsedTime: 4_000,
        movingTime: 3_700,
        distance: 32_400.75,
        totalElevationGain: nil,
        averageHeartrate: nil
    )
}
