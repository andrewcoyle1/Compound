//
//  BodyMeasurementEntryTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// A body measurement entry and the copy-on-write update it offers.
///
/// Every field is optional and independent — someone who measures their waist has not thereby said
/// anything about their calves — so the thing worth testing is that updating one circumference
/// leaves the other twenty alone. The update goes through a switch of twenty cases, which is
/// exactly the shape of code where one line gets pasted and not quite edited.
@MainActor
struct BodyMeasurementEntryTests {

    private let date = Date(timeIntervalSince1970: 1_000_000)

    private func entry(
        weightKg: Double? = 72.5,
        waist: Double? = nil,
        leftBicep: Double? = nil
    ) -> BodyMeasurementEntry {
        BodyMeasurementEntry(
            id: "entry-1",
            authorId: "author-1",
            weightKg: weightKg,
            waistCircumference: waist,
            leftBicepCircumference: leftBicep,
            date: date,
            source: .manual,
            dateCreated: date
        )
    }

    /// Every circumference on an entry, by name, so a test can check the others were untouched.
    private func circumferences(_ entry: BodyMeasurementEntry) -> [String: Double?] {
        [
            "neck": entry.neckCircumference,
            "shoulder": entry.shoulderCircumference,
            "bust": entry.bustCircumference,
            "chest": entry.chestCircumference,
            "waist": entry.waistCircumference,
            "hip": entry.hipCircumference,
            "leftBicep": entry.leftBicepCircumference,
            "rightBicep": entry.rightBicepCircumference,
            "leftForearm": entry.leftForearmCircumference,
            "rightForearm": entry.rightForearmCircumference,
            "leftWrist": entry.leftWristCircumference,
            "rightWrist": entry.rightWristCircumference,
            "leftThigh": entry.leftThighCircumference,
            "rightThigh": entry.rightThighCircumference,
            "leftCalf": entry.leftCalfCircumference,
            "rightCalf": entry.rightCalfCircumference,
            "leftAnkle": entry.leftAnkleCircumference,
            "rightAnkle": entry.rightAnkleCircumference
        ]
    }

    /// Each update paired with the field it should write to.
    private var everyUpdate: [(name: String, update: BodyMeasurementEntry.CircumferenceUpdate)] {
        [
            ("neck", .neck(38)),
            ("shoulder", .shoulder(120)),
            ("bust", .bust(100)),
            ("chest", .chest(102)),
            ("waist", .waist(81)),
            ("hip", .hip(98)),
            ("leftBicep", .leftBicep(36)),
            ("rightBicep", .rightBicep(37)),
            ("leftForearm", .leftForearm(29)),
            ("rightForearm", .rightForearm(30)),
            ("leftWrist", .leftWrist(17)),
            ("rightWrist", .rightWrist(18)),
            ("leftThigh", .leftThigh(58)),
            ("rightThigh", .rightThigh(59)),
            ("leftCalf", .leftCalf(38)),
            ("rightCalf", .rightCalf(39)),
            ("leftAnkle", .leftAnkle(22)),
            ("rightAnkle", .rightAnkle(23))
        ]
    }

    // MARK: - Initialization

    @Test("Test An Entry Records Only What It Was Given")
    func testAnEntryRecordsOnlyWhatItWasGiven() {
        let entry = entry(weightKg: 72.5)

        #expect(entry.weightKg == 72.5)
        #expect(entry.bodyFatPercentage == nil)
        #expect(entry.notes == nil)
        #expect(entry.deletedAt == nil)
        #expect(entry.healthKitUUID == nil)
        #expect(circumferences(entry).values.allSatisfy { $0 == nil })
    }

    @Test("Test An Entry Can Hold Nothing But A Date")
    func testAnEntryCanHoldNothingButADate() {
        let empty = BodyMeasurementEntry(authorId: "author-1", date: date, source: .manual, dateCreated: date)

        #expect(empty.weightKg == nil)
        #expect(empty.date == date)
        #expect(!empty.id.isEmpty)
    }

    // MARK: - Updating one measurement

    /// The heart of it: each of the twenty updates writes to its own field and nothing else. A
    /// mis-pasted case in the switch — left calf writing to right calf — fails here.
    @Test("Test Each Update Writes Only Its Own Measurement")
    func testEachUpdateWritesOnlyItsOwnMeasurement() {
        for (name, update) in everyUpdate {
            let updated = entry().withUpdated(update)
            let after = circumferences(updated)

            #expect(after[name] ?? nil != nil, "\(name) was not written")
            for (otherName, value) in after where otherName != name {
                #expect(value == nil, "updating \(name) also wrote \(otherName)")
            }
        }
    }

    @Test("Test An Update Keeps The Value It Was Given")
    func testAnUpdateKeepsTheValueItWasGiven() {
        #expect(entry().withUpdated(.waist(81.5)).waistCircumference == 81.5)
        #expect(entry().withUpdated(.rightThigh(59.25)).rightThighCircumference == 59.25)
    }

    @Test("Test An Update Replaces An Earlier Measurement")
    func testAnUpdateReplacesAnEarlierMeasurement() {
        let updated = entry(waist: 84).withUpdated(.waist(81))

        #expect(updated.waistCircumference == 81)
    }

    /// Measuring a bicep must not discard the weight logged on the same day.
    @Test("Test An Update Keeps Everything Else On The Entry")
    func testAnUpdateKeepsEverythingElseOnTheEntry() {
        let original = entry(weightKg: 72.5, waist: 81)
        let updated = original.withUpdated(.leftBicep(36))

        #expect(updated.weightKg == 72.5)
        #expect(updated.waistCircumference == 81)
        #expect(updated.leftBicepCircumference == 36)
        #expect(updated.id == original.id)
        #expect(updated.authorId == original.authorId)
        #expect(updated.date == original.date)
        #expect(updated.dateCreated == original.dateCreated)
    }

    /// Left and right are measured separately, and one must never write the other.
    @Test("Test Left And Right Are Independent")
    func testLeftAndRightAreIndependent() {
        let updated = entry().withUpdated(.leftCalf(38)).withUpdated(.rightCalf(39))

        #expect(updated.leftCalfCircumference == 38)
        #expect(updated.rightCalfCircumference == 39)
    }

    @Test("Test Updates Accumulate")
    func testUpdatesAccumulate() {
        var updated = entry()
        for (_, update) in everyUpdate {
            updated = updated.withUpdated(update)
        }

        let after = circumferences(updated)
        #expect(after.values.allSatisfy { $0 != nil })
        #expect(after.count == 18)
    }

    // MARK: - Codable

    @Test("Test An Entry Round Trips")
    func testAnEntryRoundTrips() throws {
        let original = entry(weightKg: 72.5, waist: 81, leftBicep: 36)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode(BodyMeasurementEntry.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.weightKg == original.weightKg)
        #expect(decoded.waistCircumference == original.waistCircumference)
        #expect(decoded.leftBicepCircumference == original.leftBicepCircumference)
        #expect(decoded.source == original.source)
    }

    // MARK: - Identity

    @Test("Test Entries Are Equal When Their Contents Match")
    func testEntriesAreEqualWhenTheirContentsMatch() {
        #expect(entry(waist: 81) == entry(waist: 81))
        #expect(entry(waist: 81) != entry(waist: 82))
    }

    @Test("Test An Entry Is Identified By Its Id")
    func testAnEntryIsIdentifiedByItsId() {
        #expect(entry().id == "entry-1")
    }
}
