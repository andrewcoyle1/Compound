//
//  BodyweightLoadTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// A movement's bodyweight contribution: the kilograms it lifts, the effective load, the "BW"
/// labels and the volume they add up to.
@MainActor
struct BodyweightLoadTests {

    private func set(reps: Int?, weightKg: Double?, side: SetSide? = nil) -> WorkoutSetModel {
        WorkoutSetModel(id: "s1", authorId: "author-1", index: 1, reps: reps, weightKg: weightKg, side: side, isWarmup: false, completedAt: nil, dateCreated: Date())
    }

    @Test("Test The Contribution Is The Percent Of Bodyweight")
    func testContribution() throws {
        let kilograms = try #require(BodyweightLoad.contributionKg(bodyweightKg: 80, percent: 63))
        #expect(abs(kilograms - 50.4) < 0.0001)
        #expect(BodyweightLoad.contributionKg(bodyweightKg: 80, percent: 100) == 80)
        #expect(BodyweightLoad.contributionKg(bodyweightKg: 80, percent: 0) == 0)
        #expect(BodyweightLoad.contributionKg(bodyweightKg: 80, percent: 150) == 80)
    }

    @Test("Test No Bodyweight Means No Contribution")
    func testNoBodyweight() {
        #expect(BodyweightLoad.contributionKg(bodyweightKg: nil, percent: 63) == nil)
        #expect(BodyweightLoad.contributionKg(bodyweightKg: 0, percent: 63) == nil)
        #expect(BodyweightContribution(percent: 63, bodyweightKg: nil, unit: .kilograms).contributionKg == nil)
    }

    @Test("Test The Effective Load Adds The External Load, And Assistance Takes Off It")
    func testEffective() {
        #expect(BodyweightLoad.effectiveKg(external: 20, contribution: 80) == 100)
        #expect(BodyweightLoad.effectiveKg(external: nil, contribution: 80) == 80)
        #expect(BodyweightLoad.effectiveKg(external: -30, contribution: 80) == 50)
        #expect(BodyweightLoad.effectiveKg(external: -100, contribution: 80) == 0)
        #expect(BodyweightLoad.effectiveKg(external: 20, contribution: nil) == 20)
    }

    @Test("Test The Labels Read BW Plus, BW Minus And BW")
    func testLabels() {
        let kg20 = Format.weight(kg: 20, unit: .kilograms)
        #expect(BodyweightLoad.label(weightKg: 20, unit: .kilograms, showsBodyweight: true) == "BW + \(kg20)")
        #expect(BodyweightLoad.label(weightKg: -20, unit: .kilograms, showsBodyweight: true) == "BW − \(kg20)")
        #expect(BodyweightLoad.label(weightKg: nil, unit: .kilograms, showsBodyweight: true) == "BW")
        #expect(BodyweightLoad.label(weightKg: 0, unit: .kilograms, showsBodyweight: true) == "BW")
    }

    @Test("Test The Labels Use The Exercise's Unit")
    func testPounds() {
        let pounds = Format.weight(kg: 20, unit: .pounds)
        #expect(pounds.hasSuffix("lb"))
        #expect(BodyweightLoad.label(weightKg: 20, unit: .pounds, showsBodyweight: true) == "BW + \(pounds)")
    }

    @Test("Test Without Bodyweight A Label Is The Plain Weight")
    func testLabelsOff() {
        #expect(BodyweightLoad.label(weightKg: 20, unit: .kilograms, showsBodyweight: false) == Format.weight(kg: 20, unit: .kilograms))
        #expect(BodyweightLoad.label(weightKg: nil, unit: .kilograms, showsBodyweight: false) == nil)
        #expect(BodyweightLoad.label(weightKg: -20, unit: .kilograms, showsBodyweight: false) == nil)
    }

    @Test("Test Volume Counts The Effective Load")
    func testVolume() {
        #expect(BodyweightLoad.volumeKg(of: set(reps: 8, weightKg: 20), contributionKg: 80) == 800)
        #expect(BodyweightLoad.volumeKg(of: set(reps: 8, weightKg: nil), contributionKg: 80) == 640)
        #expect(BodyweightLoad.volumeKg(of: set(reps: 8, weightKg: -30), contributionKg: 80) == 400)
        // A weight per side counts twice, as `volumeKg` has it; the bodyweight once.
        #expect(BodyweightLoad.volumeKg(of: set(reps: 10, weightKg: 10, side: .both), contributionKg: 50) == 700)
        #expect(BodyweightLoad.volumeKg(of: set(reps: nil, weightKg: 20), contributionKg: 80) == nil)
    }

    @Test("Test With No Contribution Volume Is The Set's Own")
    func testVolumeWithoutContribution() {
        let plain = set(reps: 8, weightKg: 20)
        #expect(BodyweightLoad.volumeKg(of: plain, contributionKg: nil) == plain.volumeKg)
        #expect(BodyweightLoad.volumeKg(of: plain, contributionKg: 0) == plain.volumeKg)
    }
}
