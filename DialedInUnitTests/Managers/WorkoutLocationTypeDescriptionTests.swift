//
//  WorkoutLocationTypeDescriptionTests.swift
//  DialedInUnitTests
//

import HealthKit
import Testing
@testable import DialedIn

struct WorkoutLocationTypeDescriptionTests {

    @Test("Test Known Location Types Keep Their Names")
    func testKnownLocationTypesKeepTheirNames() {
        #expect(HKWorkoutSessionLocationType.indoor.description == "Indoor")
        #expect(HKWorkoutSessionLocationType.outdoor.description == "Outdoor")
        #expect(HKWorkoutSessionLocationType.unknown.description == "Unknown")
    }

    /// A raw value from a future SDK used to hit `fatalError`.
    @Test("Test An Unrecognised Location Type Describes As Unknown")
    func testAnUnrecognisedLocationTypeDescribesAsUnknown() throws {
        let future = try #require(HKWorkoutSessionLocationType(rawValue: 99))
        #expect(future.description == "Unknown")
    }
}
