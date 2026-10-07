//
//  ExerciseNameMatcherTests.swift
//  CompoundUnitTests
//
//  Matching a sheet's names to the library without ever guessing.
//

import Testing
import Foundation
@testable import Compound

struct ExerciseNameMatcherTests {

    private let matcher = ExerciseNameMatcher(library: [
        ProgramFixtures.exercise("Dumbbell Bench Press"),
        ProgramFixtures.exercise("Barbell Row"),
        ProgramFixtures.exercise("Single-Arm Cable Row"),
        ProgramFixtures.exercise("Smith Machine Squat"),
        ProgramFixtures.exercise("Lat Pull-Down"),
        ProgramFixtures.exercise("Cable Fly"),
        ProgramFixtures.exercise("Leg Curl", alternateNames: ["Hamstring Curl"])
    ])

    private func matched(_ name: String) -> String? {
        matcher.match(name)?.name
    }

    @Test("Test The Exact Name Matches")
    func testExact() {
        #expect(matched("Barbell Row") == "Barbell Row")
    }

    @Test("Test An Alternate Name Matches")
    func testAlternateName() {
        #expect(matched("Hamstring Curl") == "Leg Curl")
    }

    @Test("Test Case And Punctuation Are Ignored")
    func testCaseAndPunctuation() {
        #expect(matched("LEG-CURL") == "Leg Curl")
        #expect(matched("lat pull down") == "Lat Pull-Down")
        #expect(matched("  barbell row ") == "Barbell Row")
    }

    @Test("Test Each Abbreviation Is Spelled Out", arguments: [
        ("DB Bench Press", "Dumbbell Bench Press"),
        ("BB Row", "Barbell Row"),
        ("1-Arm Cable Row", "Single-Arm Cable Row"),
        ("One-Arm Cable Row", "Single-Arm Cable Row"),
        ("SM Squat", "Smith Machine Squat"),
        ("Lat Pulldown", "Lat Pull-Down"),
        ("Cable Flye", "Cable Fly")
    ])
    func testExpansions(sheet: String, library: String) {
        #expect(matched(sheet) == library)
    }

    @Test("Test A Near Miss Stays Unmatched", arguments: ["Leg Curls", "Dumbbell Press", "Row", "Cable Flyes", "Seated Leg Curl"])
    func testNearMiss(name: String) {
        #expect(matched(name) == nil)
    }

    @Test("Test A Loose Match To Two Exercises Matches Neither")
    func testAmbiguous() {
        var own = ProgramFixtures.exercise("Pull Down", system: false)
        own.id = "user-pull-down"
        let matcher = ExerciseNameMatcher(library: [ProgramFixtures.exercise("Pull-Down"), own])
        #expect(matcher.match("pull down") == nil)
        #expect(matcher.match("Pulldown") == nil)
        #expect(matcher.match("Pull-Down")?.name == "Pull-Down")
    }
}
