//
//  ProgramImporterTests.swift
//  CompoundUnitTests
//
//  A parsed program as mesocycles in a macrocycle: blocks, weekly overrides, supersets, double
//  entries, rest days, techniques, effort, and the single values ranges import as.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct ProgramImporterTests {

    private func build(_ sheet: ProgramSheet? = nil) throws -> ProgramImportResult {
        try ProgramImporter.build(sheet ?? ProgramFixtures.xlsxSheet(), style: ProgramFixtures.style, resolve: ProgramFixtures.resolve())
    }

    private func exercise(_ result: ProgramImportResult, block: Int = 0, day: Int = 0, _ index: Int) -> WorkoutTemplateExercise {
        result.mesocycles[block].workoutTemplates[day].exercises[index]
    }

    // MARK: - Blocks

    @Test("Test Each Block Is A Mesocycle Of Its Weeks In A Macrocycle Not Started")
    func testBlocks() throws {
        let result = try build()
        #expect(result.mesocycles.map(\.name) == ["Build", "Peak"])
        #expect(result.mesocycles.map(\.numMicrocycles) == [2, 2])
        #expect(result.mesocycles.allSatisfy { $0.deload == .none && $0.authorId == "user-1" && $0.icon == "flag" })
        #expect(result.macrocycle.name == "Sample Program")
        #expect(result.macrocycle.status == .notStarted)
        #expect(result.macrocycle.mesocycleIds == result.mesocycles.map(\.id))
    }

    @Test("Test The Days Are The Templates, A Rest Day Empty And Named Rest")
    func testDays() throws {
        let result = try build()
        let days = result.mesocycles[0].workoutTemplates
        #expect(days.map(\.name) == ["Upper", "Lower", "Rest"])
        #expect(days.map(\.exercises.count) == [5, 4, 0])
    }

    @Test("Test The Same Exercise Twice In A Row Is Two Entries")
    func testDoubleEntries() throws {
        let result = try build()
        #expect(exercise(result, 2).exercise.name == "Lateral Raise")
        #expect(exercise(result, 3).exercise.name == "Lateral Raise")
        #expect(exercise(result, 2).setTargets.count == 3)
        #expect(exercise(result, 3).setTargets.count == 1)
    }

    @Test("Test An Override Appears Only Where A Week Differs From The One Before")
    func testOverrides() throws {
        let result = try build()
        let incline = exercise(result, 0)
        #expect(incline.setTargets.count == 2)
        #expect(incline.setTargetsByMicrocycle.map(\.fromMicrocycle) == [2])
        #expect(incline.setTargetsByMicrocycle.first?.setTargets.count == 3)
        #expect(result.mesocycles[0].workoutTemplates.flatMap(\.exercises).dropFirst().allSatisfy { $0.setTargetsByMicrocycle.isEmpty })

        // In the second block only the row's last-set RIR changes in week 2.
        let row = exercise(result, block: 1, 1)
        #expect(row.setTargets.map(\.rirTarget) == [2, 1, 1])
        #expect(row.setTargetsByMicrocycle.map(\.fromMicrocycle) == [2])
        #expect(row.setTargetsByMicrocycle.first?.setTargets.map(\.rirTarget) == [2, 1, 0])
        #expect(result.mesocycles[1].workoutTemplates.flatMap(\.exercises).filter { !$0.setTargetsByMicrocycle.isEmpty }.count == 1)
    }

    @Test("Test Rows Sharing A Superset Tag Share A Group")
    func testSupersets() throws {
        let result = try build()
        let group = try #require(exercise(result, 0).supersetGroupId)
        #expect(exercise(result, 1).supersetGroupId == group)
        #expect(exercise(result, 2).supersetGroupId == nil)
        #expect(exercise(result, day: 1, 0).supersetGroupId == nil)
    }

    @Test("Test The Plan Fields: Notes, Link, Substitutions")
    func testPlanFields() throws {
        let result = try build()
        let incline = exercise(result, 0)
        #expect(incline.notes == "Pause at the bottom.")
        #expect(incline.linkURL == "https://example.com/videos/incline-press")
        #expect(incline.substituteExerciseIds == ["ex-machine-press", "ex-dumbbell-press"])
        #expect(exercise(result, 1).substituteExerciseIds == ["ex-cable-row"])
    }

    // MARK: - Techniques

    @Test("Test Each Technique Becomes The Last Set's Type")
    func testTechniques() throws {
        let result = try build()
        func last(_ block: Int, _ day: Int, _ index: Int) -> SetTarget? {
            exercise(result, block: block, day: day, index).setTargets.last
        }
        #expect(last(0, 0, 0)?.setType == .amrap)
        #expect(last(0, 0, 0)?.rirTarget == 0)
        #expect(exercise(result, 0).setTargets.first?.setType == .standard)
        #expect(last(0, 0, 1)?.setType == .myo)
        #expect(last(0, 0, 1)?.miniSetCount == 3)
        #expect(last(0, 0, 2)?.setType == .drop)
        #expect(last(0, 0, 2)?.dropCount == 2)
        #expect(last(0, 0, 2)?.dropStepPercent == 25)
        #expect(last(0, 0, 3)?.setType == .standard)
        #expect(last(0, 0, 4)?.setType == .partials)
        #expect(last(0, 1, 0)?.setType == .standard)
        #expect(last(0, 1, 1)?.setType == .stretch)
        #expect(last(0, 1, 1)?.holdSeconds == 30)
        #expect(last(0, 1, 2)?.setType == .hold)
        #expect(last(0, 1, 2)?.holdSeconds == 20)
        #expect(last(0, 1, 3)?.setType == .partials)
        #expect(last(1, 0, 2)?.dropCount == 3)
        #expect(last(1, 0, 2)?.dropStepPercent == 20)
        #expect(last(1, 0, 3)?.setType == .partials)
    }

    // MARK: - Values

    @Test("Test Early RPE Sets Every Set But The Last, Last RPE The Last")
    func testEffort() throws {
        let result = try build()
        #expect(exercise(result, 1).setTargets.map(\.rirTarget) == [2, 2, 1])
        #expect(exercise(result, 0).setTargets.map(\.rirTarget) == [2, 0])
        #expect(exercise(result, 3).setTargets.map(\.rirTarget) == [0])
        #expect(exercise(result, block: 1, 2).setTargets.map(\.rirTarget) == [1, 0])
    }

    @Test("Test RIR Is Ten Less The Upper RPE, Rounded Down And Kept To 0 To 5", arguments: [
        (ValueRange(low: 7, high: 8), 2), (ValueRange(9.5), 0), (ValueRange(10), 0), (ValueRange(3), 5), (ValueRange(8.5), 1)
    ])
    func testRIRFromRPE(rpe: ValueRange, rir: Int) {
        #expect(ProgramImporter.rir(fromRPE: rpe) == rir)
    }

    @Test("Test Rest Is The Midpoint Rounded To 15 Seconds, None For A Dash")
    func testRest() throws {
        let result = try build()
        #expect(exercise(result, 0).restSeconds == nil)
        #expect(exercise(result, 1).restSeconds == 90)
        #expect(exercise(result, 2).restSeconds == 45)
        #expect(exercise(result, day: 1, 0).restSeconds == 180)
    }

    @Test("Test Warm-ups Are The Upper Bound, Nil When Absent")
    func testWarmups() throws {
        let result = try build()
        #expect(exercise(result, 0).warmupSetCount == 3)
        #expect(exercise(result, 2).warmupSetCount == 1)
        #expect(exercise(result, 3).warmupSetCount == 0)
        #expect(exercise(result, 4).warmupSetCount == nil)
        #expect(exercise(result, day: 1, 0).warmupSetCount == 4)
    }

    @Test("Test Reps Are The Range, A Fixed Value Both Ends, Per Side Unchanged")
    func testReps() throws {
        let result = try build()
        #expect(exercise(result, 0).setTargets.allSatisfy { $0.minReps == 6 && $0.maxReps == 8 })
        #expect(exercise(result, 3).setTargets.first?.minReps == 20 && exercise(result, 3).setTargets.first?.maxReps == 20)
        let split = exercise(result, day: 1, 1)
        #expect(split.setTargets.first?.minReps == 10 && split.setTargets.first?.maxReps == 10)
        #expect(split.exercise.laterality == .bilateral)
    }

    // MARK: - Errors

    @Test("Test A Week Whose Exercises Differ From Week 1 Names The Week And Day")
    func testExercisesDiffer() throws {
        var sheet = try ProgramFixtures.csvSheet()
        sheet.blocks[0].weeks[1].days[1].rows[0].exerciseName = "Hack Squat"
        #expect(throws: ProgramImportError.exercisesDiffer(week: "Week 2", day: "Lower", row: 22)) {
            try build(sheet)
        }
    }

    @Test("Test A Week Whose Days Differ From Week 1 Is An Error")
    func testDaysDiffer() throws {
        var sheet = try ProgramFixtures.csvSheet()
        sheet.blocks[1].weeks[1].days.removeLast()
        #expect(throws: ProgramImportError.daysDiffer(week: "Week 2", row: 41)) {
            try build(sheet)
        }
    }

    @Test("Test Nothing Is Built Until Every Name Resolves")
    func testUnmatched() throws {
        let sheet = try ProgramFixtures.csvSheet()
        let library = ProgramFixtures.library.filter { !["Row", "Leg Press"].contains($0.name) }
        #expect(ProgramImporter.unmatchedNames(in: sheet, resolve: ProgramFixtures.resolve(library)) == ["Row", "Leg Press"])
        #expect(throws: ProgramImportError.unmatchedExercises(["Row", "Leg Press"])) {
            try ProgramImporter.build(sheet, style: ProgramFixtures.style, resolve: ProgramFixtures.resolve(library))
        }
    }

    // MARK: - JSON

    @Test("Test The App's JSON Imports As The User's Own Copies")
    func testJSON() throws {
        let mesocycles = try ProgramImporter.mesocycles(fromJSON: ProgramFixtures.data("sample-program.json"))
        #expect(mesocycles.map(\.name) == ["Build", "Peak"])

        let library = ProgramFixtures.library.filter { $0.name != "Calf Raise" }
        let style = ProgramImportStyle(authorId: "user-2", icon: "x", colour: "#FFFFFF")
        let result = try ProgramImporter.build(mesocycles, title: "sample-program", style: style, library: library)
        #expect(result.mesocycles.map(\.name) == ["Build", "Peak"])
        #expect(result.mesocycles.map(\.workoutTemplates.count) == [3, 3])
        #expect(result.mesocycles.allSatisfy { $0.authorId == "user-2" && $0.icon == "flag" })
        #expect(Set(result.mesocycles.map(\.id)).isDisjoint(with: mesocycles.map(\.id)))
        #expect(result.macrocycle.name == "sample-program")
        #expect(result.macrocycle.status == .notStarted)
        #expect(result.mesocycles[0].workoutTemplates[0].exercises[0].setTargetsByMicrocycle.map(\.fromMicrocycle) == [2])
        // Someone else's exercise, used by both blocks, is copied once.
        #expect(result.newExercises.map(\.name) == ["Calf Raise"])
        #expect(result.newExercises.first?.authorId == "user-2")
    }

    @Test("Test A Single Mesocycle Object Is Accepted, And Anything Else Is Unreadable")
    func testJSONShapes() throws {
        let mesocycles = try ProgramImporter.mesocycles(fromJSON: ProgramFixtures.data("sample-program.json"))
        let single = try JSONEncoder().encode(mesocycles[1])
        #expect(try ProgramImporter.mesocycles(fromJSON: single).map(\.name) == ["Peak"])
        #expect(throws: ProgramImportError.unreadableFile) {
            try ProgramImporter.mesocycles(fromJSON: Data("{\"name\": 1}".utf8))
        }
    }
}
