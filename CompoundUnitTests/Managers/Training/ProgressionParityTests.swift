//
//  ProgressionParityTests.swift
//  CompoundUnitTests
//
//  The Flutter app's `training_rules` package is a Dart port of `ProgressionEngine`,
//  `WeightRoundingRule` (with `WeightStep` and `PlateCalculator` under it) and `MesocycleDeload`.
//  CompoundUnitTests/Fixtures/progression-parity.json holds a few hundred deterministic cases,
//  generated here from a seeded generator, with what the Swift answers for each. This side checks
//  the fixture still matches the Swift, and the Dart side checks its port against the same file,
//  so a change to either that the other has not followed fails.
//
//  To regenerate after changing the Swift (then update the Dart until it passes):
//
//      TEST_RUNNER_RECORD_PARITY=1 xcodebuild test … \
//        -only-testing:CompoundUnitTests/ProgressionParityTests
//
//  xcodebuild strips the TEST_RUNNER_ prefix, so the test reads RECORD_PARITY.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct ProgressionParityTests {

    private static let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/progression-parity.json")

    private static var isRecording: Bool {
        ProcessInfo.processInfo.environment["RECORD_PARITY"] == "1"
    }

    @Test("Test Progression Matches The Parity Fixture")
    func testFixture() throws {
        if Self.isRecording {
            try Self.lines(Self.generate()).write(to: Self.fixtureURL, atomically: true, encoding: .utf8)
            return
        }
        let data = try Data(contentsOf: Self.fixtureURL)
        let fixture = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        for (key, run) in Self.runners {
            let cases = try #require(fixture[key] as? [[String: Any]], "\(key) is missing")
            #expect(!cases.isEmpty)
            for (index, testCase) in cases.enumerated() {
                let actual = run(testCase["input"] as? [String: Any] ?? [:])
                #expect(CoachParityTests.matches(actual, testCase["expected"] ?? NSNull()), "\(key)[\(index)]: Swift gives \(actual)")
            }
        }
    }

    /// The fixture with one case per line, so a regenerated file diffs case by case.
    private static func lines(_ fixture: [String: Any]) throws -> String {
        let sections = try fixture.keys.sorted().map { key -> String in
            let cases = try (fixture[key] as? [Any] ?? []).map { testCase in
                String(bytes: try JSONSerialization.data(withJSONObject: testCase, options: [.sortedKeys]), encoding: .utf8) ?? ""
            }
            return "  \"\(key)\": [\n    " + cases.joined(separator: ",\n    ") + "\n  ]"
        }
        return "{\n" + sections.joined(separator: ",\n") + "\n}\n"
    }

    private static var runners: [String: ([String: Any]) -> Any] {
        [
            "suggest": { Self.suggest($0) },
            "suggestMissing": { Self.suggest($0) },
            "adjustRemaining": { Self.adjustRemaining($0) },
            "rounding": { Self.rounding($0) },
            "keptSets": { Self.keptSets($0) }
        ]
    }

    // MARK: - Running the Swift

    private static func suggest(_ input: [String: Any]) -> Any {
        let rule = makeRule(input["rule"])
        let ceiling = input["amrapCeiling"] as? Int
        let suggestion = ProgressionEngine().suggest(ProgressionInput(
            trackingMode: TrackingMode(rawValue: input["mode"] as? String ?? "") ?? .weightReps,
            setTargets: (input["targets"] as? [[String: Any]] ?? []).enumerated().map { makeTarget($0.offset, $0.element) },
            history: (input["history"] as? [[[String: Any]]] ?? []).map { session in
                ProgressionHistorySession(workingSets: session.enumerated().map { makeSet($0.offset, $0.element) })
            },
            adjustmentMode: ProgressionAdjustmentMode(rawValue: input["adjustment"] as? String ?? "") ?? .weightFirst,
            roundWeight: rule.round,
            minimumIncrementKg: rule.minimumIncrementKg,
            amrap: input["amrap"] as? Bool == true ? AMRAPProgression(ceiling: ceiling) : nil,
            exerciseType: (input["type"] as? String).flatMap(ExerciseType.init(rawValue:))
        ))
        return ["rationale": suggestion.rationale.rawValue, "sets": suggestion.sets.map(json)]
    }

    private static func adjustRemaining(_ input: [String: Any]) -> Any {
        let rule = makeRule(input["rule"])
        let remaining = (input["remaining"] as? [[String: Any]] ?? []).enumerated().map { makeSet($0.offset, $0.element) }
        let adjusted = ProgressionEngine().adjustRemaining(
            completed: makeSet(0, input["completed"] as? [String: Any] ?? [:]),
            target: (input["target"] as? [String: Any]).map { makeTarget(0, $0) },
            remaining: remaining,
            mode: TrackingMode(rawValue: input["mode"] as? String ?? "") ?? .weightReps,
            rounding: rule.progressionRounding,
            exerciseType: (input["type"] as? String).flatMap(ExerciseType.init(rawValue:))
        )
        return adjusted.map { suggested -> Any in suggested.map { json($0) } ?? NSNull() }
    }

    private static func rounding(_ input: [String: Any]) -> Any {
        let rule = makeRule(input["rule"])
        let weights = input["weights"] as? [Double] ?? []
        return [
            "minimumIncrementKg": rule.minimumIncrementKg,
            "round": weights.map(rule.round),
            "deload": weights.map { MesocycleDeload.lighterWeight($0, round: rule.round) }
        ]
    }

    private static func keptSets(_ input: [String: Any]) -> Any {
        let sets = (input["sets"] as? [[String: Any]] ?? []).enumerated().map { makeSet($0.offset, $0.element) }
        return MesocycleDeload.keptSets(sets).map { ["id": $0.id, "index": $0.index] }
    }

    // MARK: - Reading the input

    private static let start = Date(timeIntervalSince1970: 1_000_000)

    private static func makeSet(_ offset: Int, _ json: [String: Any]) -> WorkoutSetModel {
        var set = WorkoutSetModel(
            id: json["id"] as? String ?? "set-\(offset + 1)",
            authorId: "parity",
            index: offset + 1,
            reps: json["reps"] as? Int,
            weightKg: json["kg"] as? Double,
            durationSec: json["dur"] as? Int,
            distanceMeters: json["dist"] as? Double,
            rpe: json["rpe"] as? Double,
            side: (json["side"] as? String).flatMap(SetSide.init(rawValue:)),
            parentSetId: json["parent"] as? String,
            targetReps: json["target"] as? Int,
            isWarmup: json["warmup"] as? Bool ?? false,
            completedAt: json["open"] as? Bool == true ? nil : start,
            dateCreated: start
        )
        set.machineBaseKg = json["base"] as? Double
        return set
    }

    private static func makeTarget(_ offset: Int, _ json: [String: Any]) -> SetTarget {
        SetTarget(
            id: "target-\(offset + 1)",
            setNumber: offset + 1,
            minReps: json["min"] as? Int,
            maxReps: json["max"] as? Int,
            rirTarget: json["rir"] as? Int,
            setType: (json["type"] as? String).flatMap(SetTargetSetType.init(rawValue:)) ?? .standard,
            amrapTargetReps: json["amrap"] as? Int
        )
    }

    /// `{"step": {...}, "unit", "preferredUnit", "assisted", "bodyweightOnly"}`. A step is an
    /// increment grid, a list of weights, plates on a bar, or the no-gym fallback.
    private static func makeRule(_ value: Any?) -> WeightRoundingRule {
        let json = value as? [String: Any] ?? [:]
        let unit = ExerciseWeightUnit(rawValue: json["unit"] as? String ?? "") ?? .kilograms
        let preferred = (json["preferredUnit"] as? String).flatMap(ExerciseWeightUnit.init(rawValue:))
        let stepJSON = json["step"] as? [String: Any] ?? [:]
        var step: WeightStep
        switch stepJSON["kind"] as? String {
        case "increment":
            step = WeightStep(
                kind: .increment(stepJSON["step"] as? Double ?? 2.5, min: stepJSON["min"] as? Double ?? 0, max: stepJSON["max"] as? Double),
                chip: nil, baseWeight: nil, plates: []
            )
        case "list":
            step = WeightStep(kind: .list(stepJSON["weights"] as? [Double] ?? []), chip: nil, baseWeight: nil, plates: [])
        case "plates":
            let sleeves = stepJSON["sleeves"] as? Int ?? 2
            let plates = (stepJSON["plates"] as? [[String: Any]] ?? []).map {
                Plate(weight: $0["weight"] as? Double ?? 0, perSleeve: $0["perSleeve"] as? Int)
            }
            let bar = stepJSON["bar"] as? Double ?? 0
            step = WeightStep(
                kind: .increment((plates.first?.weight ?? 2.5) * Double(sleeves), min: bar, max: nil),
                chip: nil, baseWeight: bar, plates: plates, sleeves: sleeves
            )
        default:
            step = WeightStepper.fallback(unit)
        }
        if json["assisted"] as? Bool == true {
            step = step.assisted(bodyweightOnly: json["bodyweightOnly"] as? Bool ?? false)
        }
        return WeightRoundingRule(step: step, unit: unit, preferredUnit: preferred)
    }

    private static func json(_ suggested: SuggestedSet) -> [String: Any] {
        var json: [String: Any] = [:]
        json["kg"] = suggested.weightKg
        json["reps"] = suggested.reps
        json["dur"] = suggested.durationSec
        json["dist"] = suggested.distanceMeters
        json["target"] = suggested.targetReps
        return json
    }

    // MARK: - Generating the cases

    /// SplitMix64, so the cases come out the same on every machine.
    private struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }
    }

    private final class Generator {
        var rng = Seeded(state: 20_261_014)

        func int(_ range: ClosedRange<Int>) -> Int { Int.random(in: range, using: &rng) }
        func chance(_ odds: Double) -> Bool { Double.random(in: 0..<1, using: &rng) < odds }
        func pick<T>(_ values: [T]) -> T { values[int(0...(values.count - 1))] }
        func maybe<T>(_ odds: Double, _ value: @autoclosure () -> T) -> T? { chance(odds) ? value() : nil }

        func rule() -> [String: Any] {
            let unit = chance(0.75) ? "kilograms" : "pounds"
            var rule: [String: Any] = ["unit": unit]
            if let preferred = maybe(0.8, self.pick(["kilograms", "pounds"])) { rule["preferredUnit"] = preferred }
            switch int(0...4) {
            case 0:
                rule["step"] = ["kind": "fallback"]
            case 1:
                var step: [String: Any] = ["kind": "increment", "step": pick([1.0, 2.5, 5.0, 7.0, 10.0]), "min": pick([0.0, 5.0, 10.0])]
                if chance(0.5) { step["max"] = Double(int(8...25) * 10) }
                rule["step"] = step
            case 2:
                let gap = pick([1.0, 2.0, 2.5])
                rule["step"] = ["kind": "list", "weights": (1...int(5...25)).map { Double($0) * gap }]
            default:
                let metric = unit == "kilograms"
                let plates = (metric ? [0.5, 1.25, 2.5, 5, 10, 15, 20, 25] : [2.5, 5, 10, 25, 35, 45]).filter { _ in chance(0.8) }
                rule["step"] = [
                    "kind": "plates",
                    "bar": metric ? pick([15.0, 20.0, 0.0]) : pick([45.0, 35.0]),
                    "sleeves": pick([2, 2, 1]),
                    "plates": (plates.isEmpty ? [metric ? 2.5 : 5] : plates).map { plate -> [String: Any] in
                        var json: [String: Any] = ["weight": plate]
                        if chance(0.3) { json["perSleeve"] = int(1...4) }
                        return json
                    }
                ]
            }
            return rule
        }

        func target() -> [String: Any] {
            var json: [String: Any] = [:]
            let low = int(1...15)
            switch int(0...5) {
            case 0, 1, 2: json["min"] = low; json["max"] = low + int(-1...6)
            case 3: json["min"] = low
            case 4: json["max"] = low
            default: break
            }
            if chance(0.3) { json["rir"] = int(0...4) }
            if chance(0.25) {
                json["type"] = pick(["drop", "myo", "partials", "stretch", "hold", "failure", "amrap", "amrap", "restPause", "cluster"])
                if json["type"] as? String == "amrap", chance(0.8) { json["amrap"] = int(5...12) }
            }
            return json
        }

        func weightedSet(weight: Double?, reps: Int, failing: Bool = false) -> [String: Any] {
            var json: [String: Any] = ["reps": reps]
            json["kg"] = weight
            if failing {
                if chance(0.5) { json["rpe"] = pick([8.0, 9.0, 9.5, 10.0]) }
            } else if chance(0.6) {
                json["rpe"] = Double(int(12...20)) / 2
            }
            if chance(0.15) { json["target"] = int(5...12) }
            if chance(0.05), let weight, weight > 20 { json["base"] = 10.0 }
            if chance(0.05) { json["open"] = true }
            return json
        }

        /// One logged set of a generated history, drawn in a fixed order so the cases never change.
        func historySet(mode: String, index: Int, weight: Double, range: (bottom: Int, top: Int), missing: Bool) -> [String: Any] {
            switch mode {
            case "weightReps":
                let descending = chance(0.2) ? Double(index) * 5 : 0
                if missing, chance(0.8) {
                    return weightedSet(weight: weight - descending, reps: max(0, range.bottom - int(1...3)), failing: true)
                }
                let reps = chance(0.4) ? range.top : max(0, range.top + int(-6...3))
                return weightedSet(weight: chance(0.05) ? nil : weight - descending, reps: reps)
            case "repsOnly":
                if missing, chance(0.8) {
                    return weightedSet(weight: nil, reps: max(1, range.bottom - int(1...3)), failing: true)
                }
                return weightedSet(weight: nil, reps: max(1, range.top + int(-5...3)))
            case "timeOnly":
                var json: [String: Any] = ["dur": int(1...24) * 5]
                if chance(0.1) { json["open"] = true }
                return json
            default:
                var json: [String: Any] = ["dur": int(30...900)]
                if chance(0.95) { json["dist"] = pick([50.0, 150, 199, 200, 400, 1000, 1999, 2000, 5000, 10000]) + Double(int(0...20)) }
                if chance(0.1) { json["open"] = true }
                return json
            }
        }

        /// `missing` makes most sets fall short of their range, so resets are well covered.
        func suggestInput(missing: Bool = false) -> [String: Any] {
            let mode = pick(["weightReps", "weightReps", "weightReps", "weightReps", "repsOnly", "timeOnly", "distanceTime"])
            let targets = (0..<int(0...5)).map { _ in target() }
            let assisted = mode == "weightReps" && chance(0.1)
            var rule = rule()
            if assisted { rule["assisted"] = true; rule["bodyweightOnly"] = chance(0.5) }
            let topRange = (targets.first?["max"] as? Int) ?? (targets.first?["min"] as? Int) ?? 12
            let bottomRange = (targets.first?["min"] as? Int) ?? max(1, topRange - 4)
            var weight = Double(int(4...60)) * 2.5 * (assisted ? -0.5 : 1)
            let setCount = int(1...5)
            let history: [[[String: Any]]] = (0..<int(0...3)).map { _ in
                defer { if chance(missing ? 0.2 : 0.6) { weight -= Double(int(0...2)) * 2.5 } }
                let count = chance(0.8) ? setCount : int(1...5)
                return (0..<count).map { index in
                    historySet(mode: mode, index: index, weight: weight, range: (bottomRange, topRange), missing: missing)
                }
            }
            var input: [String: Any] = [
                "mode": mode,
                "adjustment": chance(0.7) ? "weightFirst" : "repsFirst",
                "targets": targets,
                "history": history,
                "rule": rule
            ]
            if let type = maybe(0.8, self.pick(["compoundUpper", "compoundLower", "isolationUpper", "isolationLower", "core"])) {
                input["type"] = type
            }
            if chance(0.3) {
                input["amrap"] = true
                if chance(0.7) { input["amrapCeiling"] = int(6...14) }
            }
            return input
        }

        func adjustInput() -> [String: Any] {
            let target = maybe(0.8, self.target())
            let low = (target?["min"] as? Int) ?? (target?["max"] as? Int) ?? 8
            let weight = Double(int(4...60)) * 2.5 * (chance(0.1) ? -0.5 : 1)
            var completed = weightedSet(weight: chance(0.05) ? nil : weight, reps: max(0, low + int(-4...8)))
            completed["open"] = nil
            if chance(0.1) { completed["reps"] = nil }
            var input: [String: Any] = [
                "mode": chance(0.85) ? "weightReps" : "repsOnly",
                "completed": completed,
                "remaining": (0..<int(0...3)).map { _ in ["kg": weight, "reps": low, "open": true] },
                "rule": rule()
            ]
            input["target"] = target
            if let type = maybe(0.8, self.pick(["compoundUpper", "compoundLower", "isolationUpper", "isolationLower", "core"])) {
                input["type"] = type
            }
            return input
        }

        func roundingInput() -> [String: Any] {
            var rule = rule()
            if chance(0.2) { rule["assisted"] = true; rule["bodyweightOnly"] = chance(0.5) }
            return ["rule": rule, "weights": (0..<6).map { _ in Double(int(-1200...4400)) / 20 }]
        }

        func keptSetsInput() -> [String: Any] {
            var sets: [[String: Any]] = []
            var parent: String?
            for index in 0..<int(0...12) {
                var json: [String: Any] = ["id": "s\(index)"]
                switch int(0...9) {
                case 0: json["warmup"] = true
                case 1, 2: if let parent { json["parent"] = parent }
                case 3: json["side"] = "left"
                case 4: json["side"] = "right"
                case 5: json["side"] = "both"
                default: break
                }
                if json["parent"] == nil, json["warmup"] == nil { parent = "s\(index)" }
                sets.append(json)
            }
            return ["sets": sets]
        }
    }

    private static func generate() -> [String: Any] {
        let generator = Generator()
        var fixture: [String: Any] = [:]
        let counts = ["suggest": 400, "suggestMissing": 120, "adjustRemaining": 150, "rounding": 120, "keptSets": 40]
        let inputs: [String: () -> [String: Any]] = [
            "suggest": { generator.suggestInput() },
            "suggestMissing": { generator.suggestInput(missing: true) },
            "adjustRemaining": generator.adjustInput,
            "rounding": generator.roundingInput,
            "keptSets": generator.keptSetsInput
        ]
        // A fixed order, so the generator's draws do not depend on dictionary order.
        for key in ["suggest", "suggestMissing", "adjustRemaining", "rounding", "keptSets"] {
            let make = inputs[key]!, run = runners[key]!
            fixture[key] = (0..<counts[key]!).map { _ -> [String: Any] in
                let input = make()
                return ["input": input, "expected": run(input)]
            }
        }
        return fixture
    }
}
