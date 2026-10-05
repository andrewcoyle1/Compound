//
//  StravaStrengthFileTests.swift
//  CompoundUnitTests
//
//  What a workout becomes on Strava: the JSON strength file, the description, and the form they
//  are sent in. Pure mapping, no manager.
//

import Testing
import Foundation
@testable import Compound

/// Sessions, exercises and sets for the Strava suites.
@MainActor
enum StravaFixture {
    nonisolated static let start = Date(timeIntervalSince1970: 1_700_000_000)

    static func row(
        _ id: String,
        reps: Int? = 8,
        weightKg: Double? = 100,
        durationSec: Int? = nil,
        distanceMeters: Double? = nil,
        side: SetSide? = nil,
        isWarmup: Bool = false,
        completed: Bool = true
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id, authorId: "author-1", index: 0, reps: reps, weightKg: weightKg, durationSec: durationSec,
            distanceMeters: distanceMeters, side: side, isWarmup: isWarmup, completedAt: completed ? start : nil, dateCreated: start
        )
    }

    static func exercise(_ templateId: String = "system-barbell-bench-press", name: String? = nil, sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "exercise-\(templateId)", authorId: "author-1", templateId: templateId, name: name ?? templateId,
            trackingMode: .weightReps, index: 0, sets: sets
        )
    }

    static func session(
        id: String = "session-1",
        name: String = "Push Day",
        dateCreated: Date = start,
        endedAt: Date?? = nil,
        notes: String? = nil,
        isRestDay: Bool = false,
        authorId: String = "author-1",
        exercises: [WorkoutExerciseModel]? = nil
    ) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: id,
            authorId: authorId,
            name: name,
            dateCreated: dateCreated,
            endedAt: endedAt ?? dateCreated.addingTimeInterval(600),
            notes: notes,
            exercises: exercises ?? [exercise(sets: [row("a")])],
            isRestDay: isRestDay
        )
    }
}

@MainActor
struct StravaStrengthFileTests {

    /// Elapsed time runs from start to end; active time leaves the pauses out. Both are truncated
    /// to whole seconds rather than trapping on a fractional interval.
    @Test("Test The File Carries The Start And Both Durations")
    func testTheFileCarriesTheStartAndBothDurations() throws {
        let workout = StravaFixture.session(endedAt: StravaFixture.start.addingTimeInterval(1_805.9))
        let london = try #require(TimeZone(identifier: "Europe/London"))
        let file = try #require(StravaStrengthFile(session: workout, library: [], timeZone: london))

        #expect(file.startTime == "2023-11-14T22:13:20Z")
        #expect(file.utcOffset == 0)
        #expect(file.elapsedTime == 1_805)
        #expect(file.activeTime == 1_805)
    }

    /// Strava's map counts sets, so only the work done goes: no warm-ups, nothing left unticked.
    /// A bodyweight set's zero weight is left out rather than sent as a 0 kg load.
    @Test("Test Only Completed Working Sets Are Sent")
    func testOnlyCompletedWorkingSetsAreSent() throws {
        let workout = StravaFixture.session(exercises: [StravaFixture.exercise(sets: [
            StravaFixture.row("warm", weightKg: 40, isWarmup: true),
            StravaFixture.row("done", reps: 5, weightKg: 100),
            StravaFixture.row("bodyweight", reps: 12, weightKg: 0),
            StravaFixture.row("skipped", completed: false)
        ])])

        let file = try #require(StravaStrengthFile(session: workout, library: []))

        #expect(file.sets == [
            .init(exerciseType: "BARBELL_BENCH_PRESS", repetitions: 5, weight: 100, duration: nil),
            .init(exerciseType: "BARBELL_BENCH_PRESS", repetitions: 12, weight: nil, duration: nil)
        ])
    }

    @Test("Test A Timed Set Sends Its Duration")
    func testATimedSetSendsItsDuration() throws {
        let workout = StravaFixture.session(exercises: [StravaFixture.exercise("system-ab-wheel-rollout", sets: [StravaFixture.row("hold", reps: nil, weightKg: nil, durationSec: 60)])])

        let file = try #require(StravaStrengthFile(session: workout, library: []))

        #expect(file.sets == [.init(exerciseType: "AB_WHEEL_ROLLOUT", repetitions: nil, weight: nil, duration: 60)])
    }

    /// Three sets of a single-arm row are six rows; Strava has no sides, so a left and the right
    /// after it go as the one set they are.
    @Test("Test A Left Right Pair Is Sent As One Set")
    func testALeftRightPairIsSentAsOneSet() throws {
        let workout = StravaFixture.session(exercises: [StravaFixture.exercise("system-single-arm-row", sets: [
            StravaFixture.row("l1", reps: 10, side: .left), StravaFixture.row("r1", reps: 9, side: .right),
            StravaFixture.row("l2", reps: 8, side: .left), StravaFixture.row("r2", reps: 8, side: .right)
        ])])

        let file = try #require(StravaStrengthFile(session: workout, library: []))

        #expect(file.sets.map(\.repetitions) == [10, 8])
        #expect(file.sets.allSatisfy { $0.exerciseType == "DUMBBELL_ROW" })
    }

    /// A person's own exercise has no line in the table, so it goes as the generic type for its
    /// primary muscle. One the library no longer has is left out rather than guessed.
    @Test("Test A Custom Exercise Maps By Its Primary Muscle")
    func testACustomExerciseMapsByItsPrimaryMuscle() throws {
        let custom = ExerciseModel(
            id: "custom-1", authorId: "author-1", name: "Cable Thing", trackableMetrics: [.reps, .weight],
            type: nil, laterality: nil, muscleGroups: [.triceps: .secondary, .chest: .primary],
            isBodyweight: false, rangeOfMotion: 3, stability: 3, bodyWeightContribution: 0, alternateNames: []
        )
        let workout = StravaFixture.session(exercises: [
            StravaFixture.exercise("custom-1", sets: [StravaFixture.row("a")]),
            StravaFixture.exercise("deleted-custom", sets: [StravaFixture.row("b")])
        ])

        let file = try #require(StravaStrengthFile(session: workout, library: [custom]))

        #expect(file.sets.map(\.exerciseType) == ["BENCH_PRESS_GENERIC"])
    }

    /// A built-in exercise added to the bundle without a Strava type would upload as nothing.
    @Test("Test Every Built In Exercise Has A Strava Type")
    func testEveryBuiltInExerciseHasAStravaType() throws {
        let url = try #require(Bundle.main.url(forResource: "PrebuiltExercises", withExtension: "json"))
        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let ids = try #require(json["exercises"] as? [[String: Any]]).compactMap { $0["id"] as? String }

        #expect(!ids.isEmpty)
        #expect(ids.filter { StravaExerciseType.systemExercises[$0] == nil } == [])
    }

    @Test("Test Every Muscle Has A Generic Strava Type")
    func testEveryMuscleHasAGenericStravaType() {
        #expect(Muscles.allCases.filter { StravaExerciseType.genericByMuscle[$0] == nil } == [])
    }

    // MARK: - The description

    /// The notes, then a line per exercise of what was uploaded — the same sets the file carries.
    @Test("Test The Description Is The Notes Then The Sets")
    func testTheDescriptionIsTheNotesThenTheSets() {
        let workout = StravaFixture.session(notes: "Felt strong", exercises: [
            StravaFixture.exercise(name: "Bench Press", sets: [
                StravaFixture.row("w", weightKg: 60, isWarmup: true),
                StravaFixture.row("a", reps: 8, weightKg: 100),
                StravaFixture.row("b", reps: 7, weightKg: 97.5)
            ]),
            StravaFixture.exercise("system-captains-chair-knee-raise", name: "Knee Raise", sets: [StravaFixture.row("c", reps: 12, weightKg: nil)]),
            StravaFixture.exercise("system-ab-wheel-rollout", name: "Plank", sets: [StravaFixture.row("d", reps: nil, weightKg: nil, durationSec: 60)]),
            StravaFixture.exercise(name: "Skipped", sets: [StravaFixture.row("e", completed: false)])
        ])

        let description = StravaUpload.description(for: workout, weightUnit: .kilograms, distanceUnit: .kilometers)

        #expect(description == """
        Felt strong

        Bench Press: 100 kg × 8, 97.5 kg × 7
        Knee Raise: 12 reps
        Plank: 1:00
        """)
    }

    @Test("Test The Description Uses The Users Units")
    func testTheDescriptionUsesTheUsersUnits() {
        let workout = StravaFixture.session(exercises: [StravaFixture.exercise(name: "Bench", sets: [StravaFixture.row("a", reps: 5, weightKg: 100)])])

        #expect(StravaUpload.description(for: workout, weightUnit: .pounds, distanceUnit: .kilometers) == "Bench: 220.5 lb × 5")
    }

    @Test("Test Nothing To Say Is No Description")
    func testNothingToSayIsNoDescription() {
        let workout = StravaFixture.session(notes: "  ", exercises: [StravaFixture.exercise(sets: [StravaFixture.row("a", completed: false)])])

        #expect(StravaUpload.description(for: workout, weightUnit: .kilograms, distanceUnit: .kilometers) == nil)
    }

    // MARK: - The wire format

    /// Strava's format is snake_case with a fixed version, and its keys are hand-written here
    /// rather than derived from a strategy. A set's missing measures are left out, not sent null.
    @Test("Test The File Encodes With Stravas Keys")
    func testTheFileEncodesWithStravasKeys() throws {
        let file = try #require(StravaStrengthFile(session: StravaFixture.session(), library: []))

        let json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(file)) as? [String: Any])

        #expect(json["version"] as? String == "1.0")
        #expect(json["start_time"] as? String == "2023-11-14T22:13:20Z")
        #expect(json["elapsed_time"] as? Int == 600)
        #expect(json["utc_offset"] is Int)
        #expect((json["creator"] as? [String: String])?["name"] == "Compound")
        let set = try #require((json["sets"] as? [[String: Any]])?.first)
        #expect(set["exercise_type"] as? String == "BARBELL_BENCH_PRESS")
        #expect(set["repetitions"] as? Int == 8)
        #expect(set["weight"] as? Double == 100)
        #expect(set["duration"] == nil)
    }

    @Test("Test The Upload Form Carries Its Fields And The File")
    func testTheUploadFormCarriesItsFieldsAndTheFile() throws {
        let file = try #require(StravaStrengthFile(session: StravaFixture.session(), library: []))
        let upload = StravaUpload(name: "Leg Day", description: nil, externalId: "compound-1", file: file)

        let body = try #require(String(bytes: try ProductionStravaService.multipartBody(upload, boundary: "B"), encoding: .utf8))

        #expect(body.contains("name=\"data_type\"\r\n\r\njson\r\n"))
        #expect(body.contains("name=\"sport_type\"\r\n\r\nWeightTraining\r\n"))
        #expect(body.contains("name=\"external_id\"\r\n\r\ncompound-1\r\n"))
        #expect(body.contains("name=\"name\"\r\n\r\nLeg Day\r\n"))
        #expect(!body.contains("name=\"description\""))
        #expect(body.contains("\"exercise_type\":\"BARBELL_BENCH_PRESS\""))
        #expect(body.hasSuffix("--B--\r\n"))
    }

    @Test("Test An Upload Status Decodes From Stravas JSON")
    func testAnUploadStatusDecodesFromStravasJSON() throws {
        let json = """
        {"id": 123456, "id_str": "123456", "external_id": "compound-1", "error": null,
         "status": "Your activity is ready.", "activity_id": 153243126}
        """

        let status = try JSONDecoder().decode(StravaUploadStatus.self, from: Data(json.utf8))

        #expect(status == StravaUploadStatus(id: 123_456, error: nil, activityId: 153_243_126))
        #expect(status.duplicateActivityId == nil)
    }
}
