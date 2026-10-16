//
//  TrackerParityTests.swift
//  CompoundUnitTests
//
//  The Flutter app's `training_session` package ports `WeightStepper` (an exercise's equipment in a
//  gym, resolved to a `WeightStep`) and the session a template starts (`WorkoutSessionModel`'s
//  template initializer, with `SessionLoadChoice`, `WorkingSetPrefill`, the set plan and the
//  warm-ups). CompoundUnitTests/Fixtures/tracker-parity.json holds deterministic cases built here,
//  with what the Swift answers for each: every item of the contract's full gym in both units, and
//  sessions built from templates over that gym. This side checks the fixture still matches the
//  Swift; the Dart side checks its port against the same file.
//
//  To regenerate after changing the Swift (then update the Dart until it passes):
//
//      TEST_RUNNER_RECORD_PARITY=1 xcodebuild test … \
//        -only-testing:CompoundUnitTests/TrackerParityTests
//

import Testing
import Foundation
import FirebaseFirestore
@testable import Compound

@MainActor
struct TrackerParityTests {

    private static let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/tracker-parity.json")

    private static var isRecording: Bool {
        ProcessInfo.processInfo.environment["RECORD_PARITY"] == "1"
    }

    @Test("Test The Tracker Matches The Parity Fixture")
    func testFixture() throws {
        let gym = try Self.contractGym()
        if Self.isRecording {
            let fixture: [String: Any] = [
                "weightSteps": Self.stepInputs(gym).map { ["input": $0, "expected": Self.step($0, gym: gym)] },
                "sessions": try Self.sessionInputs().map { ["input": $0, "expected": try Self.session($0, gym: gym)] }
            ]
            try Self.lines(fixture).write(to: Self.fixtureURL, atomically: true, encoding: .utf8)
            return
        }
        let data = try Data(contentsOf: Self.fixtureURL)
        let fixture = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let steps = try #require(fixture["weightSteps"] as? [[String: Any]])
        let sessions = try #require(fixture["sessions"] as? [[String: Any]])
        #expect(steps.count > 100)
        #expect(sessions.count > 3)
        for (index, testCase) in steps.enumerated() {
            let actual = Self.step(testCase["input"] as? [String: Any] ?? [:], gym: gym)
            #expect(CoachParityTests.matches(actual, testCase["expected"] ?? NSNull()), "weightSteps[\(index)]: Swift gives \(actual)")
        }
        for (index, testCase) in sessions.enumerated() {
            let actual = try Self.session(testCase["input"] as? [String: Any] ?? [:], gym: gym)
            #expect(CoachParityTests.matches(actual, testCase["expected"] ?? NSNull()), "sessions[\(index)]: Swift gives \(actual)")
        }
    }

    /// One case per line, so a regenerated file diffs case by case.
    private static func lines(_ fixture: [String: Any]) throws -> String {
        let sections = try fixture.keys.sorted().map { key -> String in
            let cases = try (fixture[key] as? [Any] ?? []).map { testCase in
                String(bytes: try JSONSerialization.data(withJSONObject: testCase, options: [.sortedKeys]), encoding: .utf8) ?? ""
            }
            return "  \"\(key)\": [\n    " + cases.joined(separator: ",\n    ") + "\n  ]"
        }
        return "{\n" + sections.joined(separator: ",\n") + "\n}\n"
    }

    // MARK: - The gym

    /// The contract's full gym profile, decoded as the app decodes it.
    private static func contractGym() throws -> GymProfileModel {
        let url = FirestoreContractTests.root.appendingPathComponent("gym_profile/full.json")
        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try Firestore.Decoder().decode(GymProfileModel.self, from: try ContractJSON.firestore(json))
    }

    // MARK: - Weight steps

    /// Every item the gym holds, one at a time and a few together, in both units; items it lacks;
    /// and assisted mirrors of a few.
    private static func stepInputs(_ gym: GymProfileModel) -> [[String: Any]] {
        var refs: [[[String: String]]] = []
        var seen = Set<String>()
        for item in gym.allEquipment where seen.insert(item.ref.id).inserted {
            refs.append([["kind": item.ref.kind.rawValue, "id": item.ref.equipmentId]])
        }
        refs += [
            [["kind": "loadableBar", "id": "barbell"], ["kind": "bands", "id": "long_elastic_bands"]],
            [["kind": "bands", "id": "short_elastic_bands"], ["kind": "loadableBar", "id": "ez_bar"]],
            [["kind": "loadableBar", "id": "barbell"], ["kind": "freeWeight", "id": "weight_plates"]],
            [["kind": "freeWeight", "id": "weight_plates"], ["kind": "loadableAccessoryEquipment", "id": "landmine"]],
            [["kind": "loadableBar", "id": "barbell"], ["kind": "loadableAccessoryEquipment", "id": "landmine"]],
            [["kind": "cableMachine", "id": "not_in_this_gym"]],
            [["kind": "bands", "id": "long_elastic_bands"], ["kind": "bands", "id": "short_elastic_bands"]]
        ]
        var inputs: [[String: Any]] = []
        for unit in ["kilograms", "pounds"] {
            for refList in refs {
                inputs.append(["refs": refList, "unit": unit, "gym": true])
            }
            inputs.append(["refs": [["kind": "loadableBar", "id": "barbell"]], "unit": unit, "gym": false])
            for (kind, id) in [("cableMachine", "cable_lat_pulldown_machine"), ("pinLoadedMachine", "pec_deck"), ("freeWeight", "dumbbells"), ("bodyWeight", "weighted_vest")] {
                for bodyweightOnly in [true, false] {
                    inputs.append(["refs": [["kind": kind, "id": id]], "unit": unit, "gym": true, "assisted": bodyweightOnly])
                }
            }
        }
        return inputs
    }

    private static func step(_ input: [String: Any], gym: GymProfileModel) -> Any {
        let refs = (input["refs"] as? [[String: String]] ?? []).compactMap { ref -> EquipmentRef? in
            guard let kind = EquipmentKind(rawValue: ref["kind"] ?? "") else { return nil }
            return EquipmentRef(kind: kind, id: ref["id"] ?? "")
        }
        let unit = ExerciseWeightUnit(rawValue: input["unit"] as? String ?? "") ?? .kilograms
        let profile = input["gym"] as? Bool == true ? gym : nil
        var step = WeightStepper.steps(for: refs, profile: profile, unit: unit)
        if let bodyweightOnly = input["assisted"] as? Bool {
            step = step.assisted(bodyweightOnly: bodyweightOnly)
        }
        let kind: Any
        switch step.kind {
        case let .increment(increment, min, max):
            kind = ["increment": increment, "min": min, "max": max.map { $0 as Any } ?? NSNull()]
        case .list(let weights):
            kind = ["list": weights]
        case .bands:
            kind = "bands"
        }
        let rule = WeightRoundingRule(step: step, unit: unit, preferredUnit: unit)
        return [
            "kind": kind,
            "baseWeight": step.baseWeight.map { $0 as Any } ?? NSNull(),
            "plates": step.plates.map { [$0.weight, $0.perSleeve.map { $0 as Any } ?? NSNull()] },
            "sleeves": step.sleeves,
            "isAssisted": step.isAssisted,
            "constrainsWeight": step.constrainsWeight,
            "bands": step.bands,
            "equipmentUnit": WeightStepper.equipmentUnit(for: refs, profile: profile)?.rawValue ?? NSNull(),
            "rounded": [-23.7, 0, 13.3, 61.3, 101.1, 187.9].map { rule.round($0) }
        ] as [String: Any]
    }

    // MARK: - Sessions from templates

    private static let created = "2026-10-01T08:00:00.000Z"

    private static func ref(_ kind: String, _ id: String) -> [String: Any] { ["kind": kind, "id": id] }

    private static func exercise(
        _ id: String,
        metrics: [String],
        type: String? = "compoundUpper",
        isBodyweight: Bool = false,
        variations: [[String: Any]]
    ) -> [String: Any] {
        var json: [String: Any] = [
            "id": id, "author_id": "parity", "name": id.replacingOccurrences(of: "_", with: " ").capitalized,
            "trackable_metrics": metrics, "muscle_groups": [String: Any](), "is_bodyweight": isBodyweight,
            "equipment_variations": variations, "range_of_motion": 3, "stability": 3,
            "body_weight_contribution": 0, "alternate_names": [String](), "is_system_exercise": false,
            "date_created": ["$timestamp": created], "date_modified": ["$timestamp": created]
        ]
        if let type { json["type"] = type }
        return json
    }

    private static func variation(_ id: String, _ resistance: [[String: Any]], support: [[String: Any]] = []) -> [String: Any] {
        ["id": id, "resistance_equipment": resistance, "support_equipment": support]
    }

    private static func target(_ number: Int, _ extra: [String: Any] = [:]) -> [String: Any] {
        ["id": "target-\(number)", "set_number": number, "set_type": "standard", "min_reps": 8, "max_reps": 12]
            .merging(extra) { $1 }
    }

    private static func slot(_ id: String, _ exercise: [String: Any], targets: [[String: Any]], extra: [String: Any] = [:]) -> [String: Any] {
        ["id": id, "exercise": exercise, "set_targets": targets, "set_rest_timers": false].merging(extra) { $1 }
    }

    private static func set(_ id: String, _ index: Int, weight: Double?, reps: Int, warmup: Bool = false, extra: [String: Any] = [:]) -> [String: Any] {
        var json: [String: Any] = [
            "id": id, "author_id": "parity", "index": index, "reps": reps, "isWarmup": warmup,
            "completed_at": ["$timestamp": "2026-09-30T08:30:00.000Z"], "date_created": ["$timestamp": "2026-09-30T08:00:00.000Z"]
        ]
        if let weight { json["weight_kg"] = weight }
        return json.merging(extra) { $1 }
    }

    /// `load` is the variation chosen, and the variations the exercise had.
    private static func pastExercise(
        _ id: String, template: String, index: Int, load: (chosen: String?, variations: [[String: Any]]), sets: [[String: Any]]
    ) -> [String: Any] {
        var json: [String: Any] = [
            "id": id, "author_id": "parity", "template_id": template, "name": template, "tracking_mode": "weightReps",
            "index": index, "sets": sets, "equipment_variations": load.variations
        ]
        if let chosen = load.chosen { json["chosen_variation_id"] = chosen }
        return json
    }

    private static func pastSession(_ id: String, day: Int, exercises: [[String: Any]]) -> [String: Any] {
        let date = ["$timestamp": String(format: "2026-09-%02dT08:00:00.000Z", day)]
        return [
            "id": id, "author_id": "parity", "name": "Push", "workout_template_id": "push", "date_created": date,
            "date_modified": date, "ended_at": date, "exercises": exercises, "is_rest_day": false,
            "liked_by_user_ids": [String](), "gym_profile_id": "gym_contract_full"
        ]
    }

    private static let barVariations = [
        variation("bar", [ref("loadableBar", "barbell"), ref("freeWeight", "weight_plates")], support: [ref("supportEquipment", "flat_bench")]),
        variation("dumbbells", [ref("freeWeight", "dumbbells")])
    ]

    /// A template over the contract gym: a bar, dumbbells a side at a time and in each hand, a
    /// cable stack, assistance, a plate-loaded machine, an exercise listed twice and a timed one,
    /// with every kind of set plan and a superset.
    private static func parityTemplate() -> [String: Any] {
        let bench = exercise("bench_press", metrics: ["weight", "reps"], variations: barVariations)
        let row = exercise(
            "one_arm_row", metrics: ["weightPerSide", "repsPerSide"],
            variations: [variation("dumbbells", [ref("freeWeight", "dumbbells")])]
        )
        let curl = exercise(
            "dumbbell_curl", metrics: ["weightPerSide", "reps"], type: "isolationUpper",
            variations: [variation("dumbbells", [ref("freeWeight", "dumbbells")])]
        )
        let pulldown = exercise(
            "lat_pulldown", metrics: ["weight", "reps"],
            variations: [variation("cable", [ref("cableMachine", "cable_lat_pulldown_machine")])]
        )
        let dip = exercise(
            "assisted_dip", metrics: ["weightPerSideAssistance", "reps"], isBodyweight: true,
            variations: [variation("machine", [ref("pinLoadedMachine", "pin-loaded_assisted_pull-up_dip_machine")]),
                         variation("pec", [ref("pinLoadedMachine", "pec_deck")])]
        )
        let hack = exercise(
            "hack_squat", metrics: ["weight", "reps"], type: "compoundLower",
            variations: [variation("hack", [ref("plateLoadedMachine", "hack_squat_machine"), ref("freeWeight", "weight_plates")])]
        )
        let plank = exercise("plank", metrics: ["duration"], type: "core", isBodyweight: true, variations: [])
        return [
            "workout_id": "push", "author_id": "parity", "name": "Push",
            "date_created": ["$timestamp": created], "date_modified": ["$timestamp": created],
            "exercises": [
                slot("s1", bench, targets: [target(1, ["min_reps": 5, "max_reps": 8, "rir_target": 2]), target(2), target(3, ["set_type": "drop", "drop_count": 2, "drop_step_percent": 15, "drop_reps": 8])]),
                slot("s2", row, targets: [target(1), target(2, ["set_type": "myo", "mini_set_count": 2])], extra: ["superset_group_id": "A", "warmup_set_count": 1]),
                slot("s3", curl, targets: [target(1, ["set_type": "amrap", "amrap_target_reps": 12]), target(2, ["set_type": "partials", "partial_reps": 5])], extra: ["superset_group_id": "A"]),
                slot("s4", pulldown, targets: [target(1), target(2, ["set_type": "hold", "hold_seconds": 20]), target(3, ["set_type": "stretch", "hold_seconds": 30])], extra: ["rest_seconds": 120, "notes": "Slow"]),
                slot("s5", dip, targets: [target(1), target(2)], extra: ["warmup_set_count": 2]),
                slot("s6", hack, targets: [target(1, ["min_reps": 6, "max_reps": 10]), target(2, ["set_type": "restPause", "mini_set_count": 1])], extra: [
                    "set_targets_by_microcycle": [["from_microcycle": 2, "set_targets": [target(1), target(2), target(3)]]]
                ]),
                slot("s7", bench, targets: [target(1, ["min_reps": 10, "max_reps": 12])]),
                slot("s8", plank, targets: [target(1)])
            ]
        ]
    }

    /// The last session of the template and the one before it.
    private static func pastSessions() -> (last: [String: Any], earlier: [String: Any]) {
        let last = pastSession("last", day: 28, exercises: [
            pastExercise("p1", template: "bench_press", index: 1, load: ("bar", barVariations), sets: [
                set("p1w", 1, weight: 40, reps: 8, warmup: true),
                set("p1a", 2, weight: 81.3, reps: 8, extra: ["rpe": 8.5]),
                set("p1b", 3, weight: 81.3, reps: 7),
                set("p1d", 4, weight: 60, reps: 6, extra: ["kind": "drop", "parent_set_id": "p1b"])
            ]),
            pastExercise("p2", template: "one_arm_row", index: 2, load: ("dumbbells", [variation("dumbbells", [ref("freeWeight", "dumbbells")])]), sets: [
                set("p2l", 1, weight: 27.5, reps: 10, extra: ["side": "left"]),
                set("p2r", 2, weight: 30, reps: 9, extra: ["side": "right"])
            ]),
            pastExercise("p3", template: "dumbbell_curl", index: 3, load: (nil, []), sets: [
                set("p3a", 1, weight: 12.5, reps: 14, extra: ["target_reps": 12])
            ]),
            pastExercise("p4", template: "lat_pulldown", index: 4, load: ("cable", []), sets: [
                set("p4a", 1, weight: 52, reps: 12), set("p4b", 2, weight: 52, reps: 12)
            ]),
            pastExercise("p5", template: "assisted_dip", index: 5, load: ("pec", []), sets: [
                set("p5a", 1, weight: -31, reps: 8)
            ]),
            pastExercise("p6", template: "bench_press", index: 7, load: ("dumbbells", barVariations), sets: [
                set("p6a", 1, weight: 30, reps: 12)
            ])
        ])
        let earlier = pastSession("earlier", day: 25, exercises: [
            pastExercise("q1", template: "bench_press", index: 1, load: ("bar", barVariations), sets: [
                set("q1a", 1, weight: 81.3, reps: 8), set("q1b", 2, weight: 81.3, reps: 8)
            ]),
            pastExercise("q4", template: "lat_pulldown", index: 4, load: ("cable", []), sets: [
                set("q4a", 1, weight: 52, reps: 12), set("q4b", 2, weight: 52, reps: 12)
            ])
        ])
        return (last, earlier)
    }

    /// What each session is built with.
    private static func sessionInputs() throws -> [[String: Any]] {
        let template = parityTemplate()
        let (last, earlier) = pastSessions()
        return [
            ["template": template, "previous": last, "history": [last, earlier], "gym": true, "prefill": "previousValues", "plansSets": false],
            ["template": template, "previous": last, "history": [last, earlier], "gym": true, "prefill": "suggestions", "plansSets": true],
            ["template": template, "previous": last, "history": [last, earlier], "gym": true, "prefill": "empty", "plansSets": true, "microcycle": 2],
            ["template": template, "previous": last, "history": [last, earlier], "gym": false, "prefill": "suggestions", "plansSets": true],
            [
                "template": template, "previous": last, "history": [last], "gym": true, "prefill": "previousValues", "plansSets": true,
                "units": ["bench_press": ["unit": "pounds", "chosen": true], "lat_pulldown": ["unit": "pounds", "chosen": false]]
            ],
            ["template": template, "gym": true, "prefill": "suggestions", "plansSets": false, "history": [[String: Any]]()]
        ]
    }

    private static func session(_ input: [String: Any], gym contractGym: GymProfileModel) throws -> Any {
        func decode<T: Decodable>(_ type: T.Type, _ json: Any?) throws -> T {
            try Firestore.Decoder().decode(type, from: try ContractJSON.firestore(json as? [String: Any] ?? [:]))
        }
        let template = try decode(WorkoutTemplateModel.self, input["template"])
        let previous = try input["previous"].map { try decode(WorkoutSessionModel.self, $0) }
        let history = try (input["history"] as? [[String: Any]] ?? []).map { try decode(WorkoutSessionModel.self, $0) }
        let gym = input["gym"] as? Bool == true ? contractGym : nil
        let microcycle = input["microcycle"] as? Int
        var units: [String: ExerciseUnitPreference] = [:]
        for (id, value) in input["units"] as? [String: [String: Any]] ?? [:] {
            units[id] = ExerciseUnitPreference(
                exerciseModelId: id,
                weightUnit: ExerciseWeightUnit(rawValue: value["unit"] as? String ?? "") ?? .kilograms,
                weightUnitIsChosen: value["chosen"] as? Bool ?? false
            )
        }
        let prefill: SessionPrefill
        switch input["prefill"] as? String {
        case "empty": prefill = .empty
        case "suggestions":
            prefill = .suggestions(Self.suggestions(
                for: template, past: (previous, history), gym: gym, units: units, microcycle: microcycle
            ))
        default: prefill = .previousValues
        }
        let session = WorkoutSessionModel(
            id: "built",
            authorId: "parity",
            template: template,
            microcycleIndex: microcycle,
            previousWorkoutSession: previous,
            gymProfile: gym,
            unitPreferences: units,
            prefill: prefill,
            plansSets: input["plansSets"] as? Bool ?? false,
            dateCreated: Samples.date("2026-10-02T08:00:00.000Z")
        )
        return Self.normalised(try ContractJSON.tagged(try Firestore.Encoder().encode(session)))
    }

    /// As `CoreInteractor.sessionPrefill`, with the session's own loads and the week's targets,
    /// history handed straight to the planner.
    private static func suggestions(
        for template: WorkoutTemplateModel,
        past: (previous: WorkoutSessionModel?, history: [WorkoutSessionModel]),
        gym: GymProfileModel?,
        units: [String: ExerciseUnitPreference],
        microcycle: Int?
    ) -> [String: ProgressionSuggestion] {
        let contexts = template.exercises.enumerated().map { index, templateExercise in
            let exercise = templateExercise.exercise
            let occurrence = template.exercises[..<index].filter { $0.exercise.id == exercise.id }.count
            let chosen = SessionLoadChoice.variationId(
                among: exercise.equipmentVariations,
                previous: past.previous?.exercise(templateId: exercise.id, occurrence: occurrence),
                previousGymId: past.previous?.gymProfileId,
                gym: gym
            )
            let refs = exercise.equipmentVariations.first { $0.id == chosen }?.resistanceEquipment
            var week = templateExercise
            week.setTargets = templateExercise.setTargets(forMicrocycle: microcycle)
            return ProgressionPlanner.ExerciseContext(
                templateExercise: week,
                preferredWeightUnit: SessionLoadChoice.weightUnit(preference: units[exercise.id], refs: refs, gym: gym),
                resistanceEquipment: refs,
                occurrence: occurrence
            )
        }
        return ProgressionPlanner.suggestions(
            for: contexts, history: past.history, adjustmentMode: .weightFirst, gymProfile: gym, amrap: AMRAPProgression(ceiling: 12)
        )
    }

    /// The session with the random ids made positional ("e1", "e1s2") and each set's creation
    /// time, which is `.now`, left out.
    static func normalised(_ session: [String: Any]) -> [String: Any] {
        var session = session
        var ids: [String: String] = [:]
        let exercises = (session["exercises"] as? [[String: Any]] ?? []).enumerated().map { position, exercise -> [String: Any] in
            var exercise = exercise
            exercise["id"] = "e\(position + 1)"
            let sets = exercise["sets"] as? [[String: Any]] ?? []
            for (row, set) in sets.enumerated() { ids[set["id"] as? String ?? ""] = "e\(position + 1)s\(row + 1)" }
            exercise["sets"] = sets.map { set -> [String: Any] in
                var set = set
                set["id"] = ids[set["id"] as? String ?? ""]
                set["date_created"] = nil
                if let parent = set["parent_set_id"] as? String { set["parent_set_id"] = ids[parent] ?? parent }
                return set
            }
            return exercise
        }
        session["exercises"] = exercises
        return session
    }
}
