//
//  ProgramFixtures.swift
//  CompoundUnitTests
//
//  The program-import fixtures in Fixtures/programs (written by make-fixture.py) and a library
//  holding every exercise the sample program names.
//

import Foundation
@testable import Compound

enum ProgramFixtures {

    static func url(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/programs/\(name)")
    }

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: url(name))
    }

    static func xlsxSheet() throws -> ProgramSheet {
        try ProgramSheetParser.parse(XLSXReader.grid(from: data("sample-program.xlsx")))
    }

    static func csvSheet() throws -> ProgramSheet {
        try ProgramSheetParser.parse(CSVReader.grid(from: data("sample-program.csv")))
    }

    static func exercise(_ name: String, system: Bool = true, alternateNames: [String] = []) -> ExerciseModel {
        ExerciseModel(
            id: "ex-" + name.lowercased().replacingOccurrences(of: " ", with: "-"),
            authorId: system ? "official" : "someone-else",
            name: name,
            trackableMetrics: [.weight, .reps],
            type: nil,
            laterality: .bilateral,
            muscleGroups: [:],
            isBodyweight: false,
            rangeOfMotion: 0,
            stability: 0,
            bodyWeightContribution: 0,
            alternateNames: alternateNames,
            isSystemExercise: system,
            dateCreated: Date(timeIntervalSinceReferenceDate: 0),
            dateModified: Date(timeIntervalSinceReferenceDate: 0)
        )
    }

    /// Every name in the sample program. "DB Press" in the sheet reaches "Dumbbell Press" through
    /// the matcher's expansion; "Calf Raise" is someone else's exercise, so a JSON import copies it.
    static let library: [ExerciseModel] = [
        "Incline Press", "Row", "Lateral Raise", "Triceps Pushdown", "Squat", "Split Squat", "Leg Curl",
        "Machine Press", "Dumbbell Press", "Cable Row", "Hack Squat", "Leg Press"
    ].map { exercise($0) } + [exercise("Calf Raise", system: false)]

    static let style = ProgramImportStyle(authorId: "user-1", icon: "flag", colour: "#000000")

    static func resolve(_ library: [ExerciseModel] = library) -> (String) -> ExerciseModel? {
        let matcher = ExerciseNameMatcher(library: library)
        return { matcher.match($0) }
    }
}
