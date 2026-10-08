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

    @Test("Test A Near Miss Stays Unmatched", arguments: ["Leg Curls", "Dumbbell Press", "Row", "Cable Flyes", "Flye"])
    func testNearMiss(name: String) {
        #expect(matched(name) == nil)
    }

    @Test("Test The Same Words In Another Order Match")
    func testReordered() {
        #expect(matched("Cable Single-Arm Row") == "Single-Arm Cable Row")
        #expect(matched("Bench Press DB") == "Dumbbell Bench Press")
    }

    /// A library name that only adds where the lift is done or what it is loaded on is the same
    /// lift; one that adds a word defining a different lift is not.
    @Test("Test A Library Name That Only Adds A Position Or Equipment Word Matches")
    func testQualifiers() {
        let matcher = ExerciseNameMatcher(library: [
            ProgramFixtures.exercise("Seated Machine Hip Adduction"),
            ProgramFixtures.exercise("Kneeling Cable Crunch"),
            ProgramFixtures.exercise("Cable Neutral Grip Lat Pulldown"),
            ProgramFixtures.exercise("Seated Plate-Loaded Machine Calf Raise"),
            ProgramFixtures.exercise("Dumbbell Concentration Curl"),
            ProgramFixtures.exercise("45° Leg Press"),
            ProgramFixtures.exercise("Calf Press on Leg Press")
        ])
        #expect(matcher.match("Machine Hip Adduction")?.name == "Seated Machine Hip Adduction")
        #expect(matcher.match("Cable Crunch")?.name == "Kneeling Cable Crunch")
        #expect(matcher.match("Neutral-Grip Lat Pulldown")?.name == "Cable Neutral Grip Lat Pulldown")
        #expect(matcher.match("Seated Calf Raise")?.name == "Seated Plate-Loaded Machine Calf Raise")
        #expect(matcher.match("Leg Press")?.name == "45° Leg Press")
        #expect(matcher.match("Dumbbell Curl") == nil)
        #expect(matcher.match("Curl") == nil)
    }

    /// A sheet name that only adds words to a library name is that lift; the longest such name
    /// wins, a one-word library name never does, and two of a length match neither.
    @Test("Test A Sheet Name That Adds Words To A Library Name Matches The Longest")
    func testContained() {
        let matcher = ExerciseNameMatcher(library: [
            ProgramFixtures.exercise("T-Bar Row"),
            ProgramFixtures.exercise("Row"),
            ProgramFixtures.exercise("Dumbbell Fly"),
            ProgramFixtures.exercise("Dumbbell Incline Fly"),
            ProgramFixtures.exercise("Seated Row"),
            ProgramFixtures.exercise("Cable Row")
        ])
        #expect(matcher.match("Chest-Supported T-Bar Row")?.name == "T-Bar Row")
        #expect(matcher.match("Bottom-Half Dumbbell Incline Fly")?.name == "Dumbbell Incline Fly")
        #expect(matcher.match("Helms Row") == nil)
        #expect(matcher.match("Seated Cable Row") == nil)
        #expect(matched("Seated Leg Curl") == "Leg Curl")
    }

    @Test("Test Parentheticals Are Optional Qualifiers On Either Side")
    func testParentheticals() {
        let matcher = ExerciseNameMatcher(library: [
            ProgramFixtures.exercise("Machine Crunch (With Overhead Handles)"),
            ProgramFixtures.exercise("Cable Overhead Triceps Extension"),
            ProgramFixtures.exercise("Barbell Romanian Deadlift"),
            ProgramFixtures.exercise("EZ Barbell Preacher Curl"),
            ProgramFixtures.exercise("Cable Pushdown")
        ])
        #expect(matcher.match("Machine Crunch")?.name == "Machine Crunch (With Overhead Handles)")
        #expect(matcher.match("Overhead Cable Triceps Extension (Rope)")?.name == "Cable Overhead Triceps Extension")
        #expect(matcher.match("Barbell RDL")?.name == "Barbell Romanian Deadlift")
        #expect(matcher.match("EZ-Bar Preacher Curl")?.name == "EZ Barbell Preacher Curl")
        #expect(matcher.match("Cable Pressdown")?.name == "Cable Pushdown")
    }

    @Test("Test Suggestions Rank By Shared Words And Stop At Three")
    func testSuggestions() {
        let names = matcher.suggestions(for: "Seated Cable Row").map(\.name)
        #expect(names.first == "Single-Arm Cable Row")
        #expect(names.contains("Barbell Row"))
        #expect(names.count <= 3)
        #expect(matcher.suggestions(for: "Nordic Ham Curl").map(\.name) == ["Leg Curl"])
        #expect(matcher.suggestions(for: "Plank").isEmpty)
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
