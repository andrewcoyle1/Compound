//
//  ProgramExerciseCoverageTests.swift
//  CompoundUnitTests
//
//  Every exercise name on the two programs the importer was built against matches the bundled
//  library, the names that already matched still match the same exercise, and the names that
//  differ only by grip or implement land on different exercises.
//

import Testing
@testable import Compound

struct ProgramExerciseCoverageTests {

    private let matcher = ExerciseNameMatcher(library: PrebuiltSeedData.exercises)

    private func matchedId(_ name: String) -> String? {
        matcher.match(name)?.id
    }

    /// The names that matched nothing before the library grew from 64 exercises.
    static let formerlyUnmatched = [
        "1-Arm Cable Pulldown", "45° Hyperextension", "45° Incline Barbell Press", "45° Incline Machine Press",
        "Bench Dip", "Bottom-Half Seated Cable Flye", "Cable Crossover Ladder", "Cable Flye", "Cable Hip Abduction",
        "Cable Hip Adduction", "Cable Lat Pullover", "Cable Pull-Through", "Cable Shoulder Press",
        "Cable Triceps Kickback", "Cable Wrist Extension", "Cable Y-Raise", "Chest-Supported DB Row",
        "Chest-Supported Machine Row", "Close-Grip Pull-Up", "Copenhagen Hip Adduction", "DB Cheat Curl", "DB Curl",
        "DB Hammer Curl", "DB Lat Pullover", "DB Lateral Raise", "DB Row", "DB Shrug", "DB Skull Crusher",
        "DB Static Lunge", "DB Step-Up", "DB Triceps Kickback", "DB Walking Lunge", "DB Wrist Curl",
        "DB Wrist Extension", "Decline Weighted Crunch", "Donkey Calf Raise", "Dual-Handle Elbows-Out Cable Row",
        "EZ-Bar Cheat Curl", "EZ-Bar Curl", "Glute Kickback", "Glute-Ham Raise", "Goblet Squat", "Hanging Leg Raise",
        "Helms Row", "Incline Chest-Supported DB Row", "Incline DB Stretch Curl", "Incline DB Y-Raise",
        "Katana Triceps Extension", "Lateral Band Walk", "Lean-Back Machine Pulldown", "Lean-In DB Lateral Raise",
        "Long-Lever Plank", "Lying Reverse DB Flye", "Machine Chest Press", "Machine Lat Pullover",
        "Machine Lateral Raise", "Machine Shrug", "Meadows Row", "Modified Candlestick", "Nordic Ham Curl", "Pull-Up",
        "Pull-Up (Wide Grip)", "Reverse Cable Crossover", "Reverse Nordic", "Roman Chair Leg Raise",
        "Seated Smith Machine Shoulder Press", "Single-Arm Machine Lateral Raise", "Sissy Squat",
        "Smith Machine Bench Press", "Smith Machine Row", "Smith Machine Static Lunge", "Standing Calf Raise",
        "Stiff-Leg Deadlift", "Swiss Ball Rollout", "Triceps Pressdown", "Triceps Pressdown (Bar)",
        "Triceps Pressdown (Rope)", "Walking Lunge", "Weighted Crunch"
    ]

    @Test func everyProgramNameMatches() {
        #expect(Self.formerlyUnmatched.count == 79)
        let unmatched = Self.formerlyUnmatched.filter { matchedId($0) == nil }
        #expect(unmatched.isEmpty, "\(unmatched)")
    }

    @Test("Spellings of an existing exercise land on it", arguments: [
        ("Pull-Up (Wide Grip)", "system-wide-grip-pull-up"),
        ("Triceps Pressdown (Bar)", "system-cable-pushdown-straight-bar"),
        ("45° Incline Barbell Press", "system-barbell-incline-bench-press"),
        ("45° Incline Machine Press", "system-lever-incline-hammer-chest-press"),
        ("Cable Triceps Kickback", "system-neutral-grip-cable-triceps-kickback"),
        ("DB Row", "system-single-arm-row"),
        ("Incline Chest-Supported DB Row", "system-chest-supported-dumbbell-row"),
        ("Cable Crossover Ladder", "system-cable-fly"),
        ("DB Cheat Curl", "system-dumbbell-curl"),
        ("EZ-Bar Cheat Curl", "system-ez-bar-curl")
    ])
    func spellings(sheet: String, id: String) {
        #expect(matchedId(sheet) == id)
    }

    @Test func gripsAndImplementsStaySeparate() {
        let pairs = [
            ("Triceps Pressdown (Rope)", "Triceps Pressdown (Bar)"),
            ("DB Curl", "EZ-Bar Curl"),
            ("Pull-Up", "Pull-Up (Wide Grip)"),
            ("Pull-Up", "Close-Grip Pull-Up"),
            ("Machine Lateral Raise", "Single-Arm Machine Lateral Raise"),
            ("Weighted Crunch", "Decline Weighted Crunch"),
            ("Cable Flye", "Reverse Cable Crossover")
        ]
        for (first, second) in pairs {
            #expect(matchedId(first) != nil)
            #expect(matchedId(first) != matchedId(second), "\(first) and \(second)")
        }
    }

    /// Names that matched before the library grew, with what they matched then. "DB Preacher
    /// Curl" is the one deliberate change: it used to fall on the EZ-bar preacher curl.
    @Test("Names that already matched still match the same exercise", arguments: [
        ("Machine Shoulder Press", "system-pin-loaded-machine-shoulder-press"),
        ("EZ-Bar Cable Curl", "system-cable-bicep-curl-straight-bar"),
        ("Neutral-Grip Pull-Up", "system-weighted-hammer-grip-pull-up-on-dip"),
        ("Wide-Grip Pull-Up", "system-wide-grip-pull-up"),
        ("Single-Arm DB Row", "system-single-arm-row"),
        ("DB Bulgarian Split Squat", "system-bulgarian-split-squat"),
        ("Smith Machine Static Lunge w/ Elevated Front Foot", "system-smith-machine-front-foot-elevated-split-squat"),
        ("Hammer Preacher Curl", "system-ez-barbell-preacher-curl"),
        ("Machine Hip Abduction", "system-seated-machine-hip-abduction"),
        ("Seated Calf Raise", "system-seated-plate-loaded-machine-calf-raise"),
        ("Bottom-Half DB Flye", "system-dumbbell-fly"),
        ("Low-to-High Cable Crossover", "system-low-to-high-cable-fly"),
        ("High-Cable Lateral Raise", "system-standing-lateral-raise-cable"),
        ("Wide-Grip Lat Pulldown", "system-wide-grip-cable-lat-pulldown"),
        ("Snatch-Grip RDL", "system-barbell-romanian-deadlift"),
        ("Machine Crunch", "system-machine-crunch-with-overhead-handles"),
        ("DB Preacher Curl", "system-dumbbell-preacher-curl")
    ])
    func previousMatches(sheet: String, id: String) {
        #expect(matchedId(sheet) == id)
    }
}
