//
//  FirestoreContractTests.swift
//  CompoundUnitTests
//
//  The Swift half of the Firestore contract (docs/specs/flutter/firestore-contract.md). The Flutter
//  app writes the same documents, and the sync engine drops any document it cannot decode without
//  an error, so the shapes in contracts/firestore/ are checked here with the real Firestore.Decoder
//  and Firestore.Encoder (what `setData(from:merge:)` and `data(as:)` use) and in Dart by
//  app/packages/compound_models/test/contract_test.dart.
//
//  Fixtures are JSON with each Timestamp tagged `{"$timestamp": "2026-01-02T03:04:05.123Z"}`
//  (UTC, exactly three fractional digits: Date holds a Double, so the contract is to the
//  millisecond), and a NaN or infinity, which JSON cannot hold, tagged `{"$double": "NaN"}`.
//  Per model:
//  - `full` and `minimal` are canonical: written from the fixed samples below, and each must
//    re-encode to exactly itself, number types included.
//  - `legacy-<name>` is an older shape Swift still reads; it must decode and re-encode to
//    `legacy-<name>.expected.json`. They are written by hand.
//  - contracts/firestore/enums.json holds every raw value the models' enums store.
//
//  Swift is the source of truth until M6. After changing a model, update the samples, then
//  re-record with `TEST_RUNNER_RECORD_CONTRACTS=1 xcodebuild test … -only-testing:
//  CompoundUnitTests/FirestoreContractTests` (xcodebuild hands TEST_RUNNER_-prefixed variables to
//  the test process without the prefix) and commit the fixtures; the Dart test then fails until
//  Dart catches up.
//

import Foundation
import Testing
import FirebaseFirestore
@testable import Compound

@MainActor
struct FirestoreContractTests {

    // MARK: - The models under contract

    struct Contract {
        let directory: String
        /// The encoded sample for each canonical case.
        let samples: [String: [String: Any]]
        /// Firestore.Decoder then Firestore.Encoder, as a real read and write would.
        let roundTrip: ([String: Any]) throws -> [String: Any]
        /// Fields the app writes or queries by name rather than through the encoder.
        let namedFields: [String]
        /// The full sample, to check it really sets every optional property.
        let fullSample: Any
    }

    static func contract<T: Codable>(
        _ type: T.Type, directory: String, full: T, minimal: T, namedFields: [String]
    ) throws -> Contract {
        let encoder = Firestore.Encoder()
        return Contract(
            directory: directory,
            samples: ["full": try encoder.encode(full), "minimal": try encoder.encode(minimal)],
            roundTrip: { try Firestore.Encoder().encode(Firestore.Decoder().decode(T.self, from: $0)) },
            namedFields: namedFields,
            fullSample: full
        )
    }

    private static func contracts() throws -> [Contract] {
        try userAndTrainingContracts() + nutritionContracts() + bodyAndGoalContracts() + libraryContracts()
            + gymContracts() + programAndFoodContracts() + checkInContracts() + socialContracts() + coachContracts()
    }

    private static func userAndTrainingContracts() throws -> [Contract] {
        [
            try contract(
                UserModel.self, directory: "user_model",
                full: Samples.fullUser, minimal: Samples.minimalUser,
                namedFields: Self.userModelNamedFields
            ),
            try contract(
                PrivateUserSettings.self, directory: "private_user_settings",
                full: Samples.fullPrivateSettings, minimal: PrivateUserSettings(),
                // Written whole through `saveDocument` (a merge), never field by field.
                namedFields: []
            ),
            try contract(
                WorkoutSessionModel.self, directory: "workout_session",
                full: Samples.fullSession, minimal: Samples.minimalSession,
                namedFields: Self.workoutSessionNamedFields
            ),
            // The session's nested types, each in its own folder so every lenient path in their
            // decoders has a case of its own. Never written or queried by field name.
            try contract(
                WorkoutExerciseModel.self, directory: "workout_exercise",
                full: Samples.fullExercise, minimal: Samples.minimalExercise, namedFields: []
            ),
            try contract(
                WorkoutSetModel.self, directory: "workout_set",
                full: Samples.fullSet, minimal: Samples.minimalSet, namedFields: []
            ),
            try contract(
                SetTarget.self, directory: "set_target",
                full: Samples.fullSetTarget, minimal: Samples.minimalSetTarget, namedFields: []
            ),
            try contract(
                EquipmentVariation.self, directory: "equipment_variation",
                full: Samples.fullEquipmentVariation, minimal: Samples.minimalEquipmentVariation, namedFields: []
            )
        ]
    }

    /// `MealItemModel`, `DailyMacroTarget` and `DietPlan` have no CodingKeys, so
    /// their keys are the camelCase property names, spelled out here.
    private static func nutritionContracts() throws -> [Contract] {
        [
            try contract(
                MealLogModel.self, directory: "meal_log",
                full: Samples.fullMealLog, minimal: Samples.minimalMealLog,
                namedFields: Self.mealLogNamedFields
            ),
            try contract(
                MealItemModel.self, directory: "meal_item",
                full: Samples.fullMealItem, minimal: Samples.minimalMealItem,
                // Read by name in `functions/coach.js`.
                namedFields: ["displayName", "nutrients"]
            ),
            try contract(
                NutrientMap.self, directory: "nutrient_map",
                full: Samples.fullNutrients, minimal: NutrientMap(),
                // `mealTotals` in `functions/coach.js` sums these four by name.
                namedFields: ([.calories, .protein, .carbs, .fatTotal] as [NutrientKey]).map(\.rawValue)
            ),
            try contract(
                DietPlan.self, directory: "diet_plan",
                full: Samples.fullDietPlan, minimal: Samples.minimalDietPlan,
                // `userId` is checked by the `diet_plans` rule; the rest are read by name in
                // `functions/coach.js`.
                namedFields: [
                    "userId", "days", "tdeeEstimate", "preferredDiet", "calorieFloor", "proteinIntake",
                    "calorieDistribution"
                ]
            ),
            try contract(
                DailyMacroTarget.self, directory: "daily_macro_target",
                full: Samples.fullDailyMacroTarget, minimal: Samples.minimalDailyMacroTarget,
                // Read by name in `functions/coach.js`.
                namedFields: ["calories", "proteinGrams", "carbGrams", "fatGrams"]
            ),
            try contract(
                FoodLogSettings.self, directory: "food_log_settings",
                full: Samples.fullFoodLogSettings, minimal: FoodLogSettings(authorId: "user_contract_minimal"),
                // Written whole through `saveDocument` (a merge), never field by field.
                namedFields: []
            )
        ]
    }

    /// Fields named in the `author_id` listener (`BodyMeasurementsManager`), the goal `status`
    /// update (`GoalManager`), the goal rule's frozen fields (`firestore.rules`), and the reads in
    /// `functions/coach.js` (`date` range queries, `deleted_at`, `number`, `daily_step_goal`, …).
    private static func bodyAndGoalContracts() throws -> [Contract] {
        [
            try contract(
                BodyMeasurementEntry.self, directory: "body_measurement",
                full: Samples.fullBodyMeasurement, minimal: Samples.minimalBodyMeasurement,
                namedFields: ([.authorId, .date, .deletedAt, .weightKg, .bodyFatPercentage] as [BodyMeasurementEntry.CodingKeys])
                    .map(\.rawValue)
            ),
            try contract(
                StepsModel.self, directory: "steps",
                full: Samples.fullSteps, minimal: Samples.minimalSteps,
                namedFields: ([.authorId, .date, .deletedAt, .number] as [StepsModel.CodingKeys]).map(\.rawValue)
            ),
            try contract(
                AnalyticsSettings.self, directory: "analytics_settings",
                full: Samples.fullAnalyticsSettings, minimal: AnalyticsSettings(authorId: "user_contract_minimal"),
                namedFields: [AnalyticsSettings.CodingKeys.dailyStepGoal.rawValue]
            ),
            try contract(
                WeightGoal.self, directory: "weight_goal",
                full: Samples.fullWeightGoal, minimal: Samples.minimalWeightGoal,
                namedFields: ([
                    .id, .userId, .startingWeightKg, .createdAt, .status, .objective, .targetWeightKg, .weeklyChangeKg
                ] as [WeightGoal.CodingKeys]).map(\.rawValue)
            )
        ]
    }

    /// Every session field the app updates or queries by name: `WorkoutSessionManager` (the
    /// `author_id` listener, the template, collection-group and notification queries, and the
    /// Strava and streak field writes), `FollowingQueries`, `FirebaseWorkoutSessionLikeService`
    /// (`liked_by_user_ids`, spelled out there) and the `onReportCreated` function (`hidden`).
    private static let workoutSessionNamedFields: [String] = ([
        .id, .authorId, .dateCreated, .workoutTemplateId, .stravaActivityId, .weekStreakCount,
        .likedByUserIds, .hidden
    ] as [WorkoutSessionModel.CodingKeys]).map(\.rawValue) + ["liked_by_user_ids"]

    /// Every meal field the app or the coach queries or reads by name: the `author_id` listener in
    /// `MealLogManager`, and `functions/coach.js` (a `date` range query, `day_key` and `items`).
    private static let mealLogNamedFields: [String] = ([
        .authorId, .date, .dayKey, .items
    ] as [MealLogModel.CodingKeys]).map(\.rawValue)

    /// Every user-document field the app updates or queries by name: `UserManager`,
    /// `EditProfilePresenter`, `ExpenditurePresenter`, `UserManager+Username`,
    /// `CoreInteractor+CircleGoals` and `FirebaseUserQueryService`. The three literals are spelled
    /// out in `UserManager` itself rather than taken from `CodingKeys`.
    private static let userModelNamedFields: [String] = ["submitted_first_name", "submitted_last_name", "submitted_email"]
        + ([
            .submittedFirstName, .submittedLastName, .submittedProfileImage, .submittedGender,
            .submittedDateOfBirth, .submittedHeightCentimeters, .submittedLengthUnitPreference,
            .submittedWeightKilograms, .submittedWeightUnitPreference, .submittedDistanceUnitPreference,
            .submittedExerciseFrequency, .submittedDailyActivityLevel, .submittedCardioFitnessLevel,
            .submittedActiveMesocycleId, .submittedFavouriteGymProfileId, .didCompleteOnboarding,
            .fcmToken, .submittedCurrentGoalId, .acceptedHealthDisclaimerVersion,
            .acceptedHealthDisclaimerDate, .acceptedHealthPrivacyPolicyVersion,
            .acceptedHealthPrivacyPolicyDate, .isPrivate, .blockedUserIds, .followingIds, .username,
            .weeklySessionGoal, .creationDate, .userId
        ] as [UserModel.CodingKeys]).map(\.rawValue)

    // MARK: - Tests

    @Test("Every contract fixture decodes with the real Firestore decoder")
    func everyFixtureDecodes() throws {
        for contract in try Self.contracts() {
            let cases = try Self.caseNames(in: contract.directory)
            #expect(cases.contains("full") && cases.contains("minimal"), "\(contract.directory) needs full and minimal")
            for name in cases {
                let document = try Self.firestoreDocument(contract.directory, name)
                #expect(throws: Never.self, "\(contract.directory)/\(name) does not decode") {
                    _ = try contract.roundTrip(document)
                }
            }
        }
    }

    @Test("Canonical fixtures match the samples and re-encode to exactly themselves")
    func canonicalFixturesRoundTrip() throws {
        let record = ProcessInfo.processInfo.environment["RECORD_CONTRACTS"] == "1"
        for contract in try Self.contracts() {
            for (name, sample) in contract.samples {
                let encodedSample = try ContractJSON.tagged(sample)
                if record { try Self.write(encodedSample, to: Self.fixtureURL(contract.directory, name)) }
                let fixture = try Self.taggedFixture(contract.directory, name)
                #expect(
                    ContractJSON.Value(fixture) == ContractJSON.Value(encodedSample),
                    "\(contract.directory)/\(name).json is not the sample: re-record with RECORD_CONTRACTS=1"
                )
                let reencoded = try ContractJSON.tagged(contract.roundTrip(try ContractJSON.firestore(fixture)))
                #expect(
                    ContractJSON.Value(reencoded) == ContractJSON.Value(fixture),
                    "\(contract.directory)/\(name) changed on a round trip"
                )
            }
        }
    }

    @Test("The full samples set every optional property")
    func fullSamplesAreFull() throws {
        for contract in try Self.contracts() {
            for child in Mirror(reflecting: contract.fullSample).children {
                let value = Mirror(reflecting: child.value)
                #expect(
                    !(value.displayStyle == .optional && value.children.isEmpty),
                    "\(contract.directory) full sample leaves \(child.label ?? "?") nil"
                )
            }
        }
    }

    @Test("Legacy fixtures decode to their expected shape")
    func legacyFixturesDecodeToExpected() throws {
        for contract in try Self.contracts() {
            for name in try Self.caseNames(in: contract.directory) where name.hasPrefix("legacy-") {
                let reencoded = try ContractJSON.tagged(contract.roundTrip(try Self.firestoreDocument(contract.directory, name)))
                let expected = try Self.taggedFixture(contract.directory, "\(name).expected")
                #expect(
                    ContractJSON.Value(reencoded) == ContractJSON.Value(expected),
                    "\(contract.directory)/\(name) does not decode to \(name).expected.json"
                )
            }
        }
    }

    @Test("Every field written or queried by name is a key in the full fixture")
    func namedFieldsAreInFullFixture() throws {
        for contract in try Self.contracts() {
            let keys = Set(try Self.taggedFixture(contract.directory, "full").keys)
            for field in contract.namedFields {
                #expect(keys.contains(field), "\(contract.directory): \(field) is not in full.json")
            }
        }
    }

    @Test("Enum raw values match contracts/firestore/enums.json")
    func enumRawValuesMatch() throws {
        // Exhaustive, so a new case fails to compile here until it is listed.
        let weightUnits: [WeightUnitPreference] = [.kilograms, .pounds]
        for unit in weightUnits {
            switch unit {
            case .kilograms, .pounds: break
            }
        }
        // Not CaseIterable, so listed here; the switch fails to compile on a new case.
        let setTypes: [SetTargetSetType] = [
            .standard, .drop, .myo, .failure, .amrap, .restPause, .cluster, .partials, .stretch, .hold
        ]
        for setType in setTypes {
            switch setType {
            case .standard, .drop, .myo, .failure, .amrap, .restPause, .cluster, .partials, .stretch, .hold: break
            }
        }
        // Not CaseIterable either.
        let timestampSides: [TimestampSide] = [.left, .right]
        for side in timestampSides {
            switch side {
            case .left, .right: break
            }
        }
        let enums: [String: [String]] = [
            "ActivityLevel": ActivityLevel.allCases.map(\.rawValue),
            "EquipmentKind": EquipmentKind.allCases.map(\.rawValue),
            "ExerciseWeightUnit": ExerciseWeightUnit.allCases.map(\.rawValue),
            "SetKind": SetKind.allCases.map(\.rawValue),
            "SetSide": SetSide.allCases.map(\.rawValue),
            "SetTargetSetType": setTypes.map(\.rawValue),
            "TrackingMode": TrackingMode.allCases.map(\.rawValue),
            "CardioFitnessLevel": CardioFitnessLevel.allCases.map(\.rawValue),
            "DistanceUnitPreference": DistanceUnitPreference.allCases.map(\.rawValue),
            "ExerciseFrequency": ExerciseFrequency.allCases.map(\.rawValue),
            "Gender": Gender.allCases.map(\.rawValue),
            "LengthUnitPreference": LengthUnitPreference.allCases.map(\.rawValue),
            "WeightUnitPreference": weightUnits.map(\.rawValue),
            "MealItemSourceType": MealItemSourceType.allCases.map(\.rawValue),
            "NutrientKey": NutrientKey.allCases.map(\.rawValue),
            "TimestampSide": timestampSides.map(\.rawValue)
        ].merging(try Self.bodyAndGoalEnums()) { $1 }.merging(Self.libraryEnums()) { $1 }
            .merging(Self.programAndFoodEnums()) { $1 }.merging(Self.checkInEnums()) { $1 }
            .merging(Self.socialEnums()) { $1 }.merging(Self.coachEnums()) { $1 }
        let url = Self.root.appendingPathComponent("enums.json")
        if ProcessInfo.processInfo.environment["RECORD_CONTRACTS"] == "1" { try Self.write(enums, to: url) }
        let fixture = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: [String]])
        #expect(fixture == enums)
    }

    /// The body and goal models' enums, exhaustive as above.
    private static func bodyAndGoalEnums() throws -> [String: [String]] {
        // None of these three is CaseIterable.
        let weightSources: [WeightSource] = [.manual, .healthkit, .imported]
        for source in weightSources {
            switch source {
            case .manual, .healthkit, .imported: break
            }
        }
        let stepsSources: [StepsSource] = [.manual, .healthkit, .imported]
        for source in stepsSources {
            switch source {
            case .manual, .healthkit, .imported: break
            }
        }
        let goalStatuses: [WeightGoal.GoalStatus] = [.active, .completed, .abandoned, .paused]
        for status in goalStatuses {
            switch status {
            case .active, .completed, .abandoned, .paused: break
            }
        }
        // No raw type: stored as a keyed map, `{"loseWeight": {}}`, so its keys are listed.
        let objectiveKeys = try OverarchingObjective.allCases.map { objective in
            try #require(try Firestore.Encoder().encode(objective).keys.first)
        }
        return [
            "WeightSource": weightSources.map(\.rawValue),
            "StepsSource": stepsSources.map(\.rawValue),
            "GoalStatus": goalStatuses.map(\.rawValue),
            "OverarchingObjective": objectiveKeys
        ]
    }

    // MARK: - Fixture files

    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("contracts/firestore")

    private static func fixtureURL(_ directory: String, _ name: String) -> URL {
        root.appendingPathComponent(directory).appendingPathComponent("\(name).json")
    }

    /// Case names in a model's folder, leaving out the `.expected` files that pair with legacy cases.
    private static func caseNames(in directory: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent(directory).path)
            .filter { $0.hasSuffix(".json") && !$0.hasSuffix(".expected.json") }
            .map { String($0.dropLast(".json".count)) }
            .sorted()
    }

    static func taggedFixture(_ directory: String, _ name: String) throws -> [String: Any] {
        let data = try Data(contentsOf: fixtureURL(directory, name))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func firestoreDocument(_ directory: String, _ name: String) throws -> [String: Any] {
        try ContractJSON.firestore(try taggedFixture(directory, name))
    }

    static func write(_ object: Any, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(try jsonText(object).utf8).write(to: url)
    }

    /// What `write` puts in a file.
    static func jsonText(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        // JSONSerialization writes `"key" : value`; the usual spelling keeps hand-written fixtures alike.
        return (String(bytes: data, encoding: .utf8) ?? "").replacingOccurrences(of: "\" : ", with: "\": ") + "\n"
    }
}

// MARK: - Fixed samples

/// What `RECORD_CONTRACTS=1` writes (the nutrition and body samples are in `Samples+Nutrition.swift` and `Samples+Body.swift`). Fixed values, never `Date()`, so a re-record changes only
/// what the model changed. Doubles are deliberately not whole numbers (JSON would write 172.0 as
/// 172, which reads back as an integer) and are exact in binary, so the JSON stays short.
enum Samples {
    static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: iso) ?? .distantPast
    }

    static let fullUser = UserModel(
        userId: "user_contract_full",
        email: "ada@example.com",
        isAnonymous: false,
        authProviders: ["google.com", "apple.com"],
        displayName: "Ada Lovelace",
        firstName: "Ada",
        lastName: "Lovelace",
        phoneNumber: "+447700900123",
        photoUrl: "https://example.com/ada.jpg",
        creationDate: date("2025-03-04T05:06:07.123Z"),
        creationVersion: "2.4.0",
        lastSignInDate: date("2026-10-01T08:09:10.456Z"),
        submittedEmail: "augusta@example.com",
        submittedFirstName: "Augusta",
        submittedLastName: "King",
        submittedProfileImage: "https://example.com/augusta.jpg",
        submittedDateOfBirth: date("1990-12-10T00:00:00.000Z"),
        submittedGender: .preferNotToSay,
        submittedHeightCentimeters: 172.5,
        submittedWeightKilograms: 64.25,
        submittedExerciseFrequency: .threeToFour,
        submittedDailyActivityLevel: .veryActive,
        submittedCardioFitnessLevel: .intermediate,
        submittedLengthUnitPreference: .inches,
        submittedWeightUnitPreference: .pounds,
        submittedDistanceUnitPreference: .miles,
        submittedCurrentGoalId: "goal_contract",
        submittedActiveMesocycleId: "mesocycle_contract",
        submittedFavouriteGymProfileId: "gym_contract",
        blockedUserIds: ["user_blocked"],
        followingIds: ["user_followed_1", "user_followed_2"],
        isPrivate: true,
        socialPushLikes: false,
        socialPushComments: true,
        socialPushFollows: false,
        socialPushNudges: true,
        socialPushMentions: false,
        fcmToken: "fcm-token-legacy",
        didCompleteOnboarding: true,
        acceptedHealthDisclaimerVersion: "2025.10.05",
        acceptedHealthDisclaimerDate: date("2025-10-06T07:08:09.010Z"),
        acceptedHealthPrivacyPolicyVersion: "2025.10.05",
        acceptedHealthPrivacyPolicyDate: date("2025-10-06T07:08:09.010Z"),
        weeklySessionGoal: 4
    ).withUsername("ada")

    static let minimalUser = UserModel(userId: "user_contract_minimal")

    static let fullEquipmentVariation = EquipmentVariation(
        id: "variation_contract_full",
        resistanceEquipment: [
            EquipmentRef(kind: .loadableBar, id: "olympic_barbell"),
            EquipmentRef(kind: .freeWeight, id: "bumper_plates")
        ],
        supportEquipment: [EquipmentRef(kind: .supportEquipment, id: "flat_bench")]
    )

    static let minimalEquipmentVariation = EquipmentVariation(id: "variation_contract_minimal")

    static let fullSetTarget = SetTarget(
        id: "set_target_contract_full",
        setNumber: 2,
        minReps: 6,
        maxReps: 10,
        rirTarget: 1,
        setType: .drop,
        dropCount: 2,
        dropStepPercent: 15,
        dropReps: 8,
        miniSetCount: 3,
        amrapTargetReps: 12,
        partialReps: 5,
        holdSeconds: 30
    )

    static let minimalSetTarget = SetTarget(id: "set_target_contract_minimal", setNumber: 1)

    static let fullSet: WorkoutSetModel = {
        var set = WorkoutSetModel(
            id: "set_contract_full",
            authorId: "user_contract_full",
            index: 3,
            reps: 8,
            weightKg: 82.5,
            durationSec: 45,
            distanceMeters: 400.5,
            rpe: 8.5,
            side: .left,
            kind: .drop,
            parentSetId: "set_contract_parent",
            targetReps: 10,
            bands: ["Red", "Blue"],
            isWarmup: false,
            completedAt: date("2026-10-12T17:41:02.750Z"),
            dateCreated: date("2026-10-12T17:30:00.250Z")
        )
        set.weightUnit = .pounds
        set.loadCount = 2
        set.machineBaseKg = 20.5
        return set
    }()

    static let minimalSet = WorkoutSetModel(
        id: "set_contract_minimal",
        authorId: "user_contract_minimal",
        index: 1,
        isWarmup: true,
        dateCreated: date("2026-10-12T17:30:00.250Z")
    )

    static let fullExercise = WorkoutExerciseModel(
        id: "exercise_contract_full",
        authorId: "user_contract_full",
        templateId: "bench_press",
        name: "Bench Press",
        trackingMode: .weightReps,
        index: 1,
        notes: "Pause on the chest",
        imageName: "bench_press",
        sets: [fullSet],
        setTargets: [fullSetTarget],
        chosenVariationId: "variation_contract_full",
        equipmentVariations: [fullEquipmentVariation],
        supersetGroupId: "superset_contract",
        planNotes: "Elbows tucked",
        planSlotId: "slot_contract",
        restSeconds: 150,
        linkURL: "https://example.com/bench",
        substituteExerciseIds: ["dumbbell_bench_press"],
        weightUnit: .pounds,
        loadsPerSet: 2,
        machineBaseKg: 20.5
    )

    static let minimalExercise = WorkoutExerciseModel(
        id: "exercise_contract_minimal",
        authorId: "user_contract_minimal",
        templateId: "plank",
        name: "Plank",
        trackingMode: .timeOnly,
        index: 1,
        sets: []
    )

    static let fullSession: WorkoutSessionModel = {
        var session = WorkoutSessionModel(
            id: "session_contract_full",
            authorId: "user_contract_full",
            name: "Push A",
            workoutTemplateId: "template_contract",
            mesocycleId: "mesocycle_contract",
            dateCreated: date("2026-10-12T17:30:00.250Z"),
            notes: "Felt strong",
            exercises: [fullExercise, minimalExercise],
            deletedAt: date("2026-10-13T09:00:00.125Z"),
            likedByUserIds: ["user_followed_1"],
            weekStreakCount: 6
        )
        session.endSession(at: date("2026-10-12T18:35:10.500Z"), pausedSeconds: 120.5)
        session.stravaActivityId = 12_345_678_901
        session.gymProfileId = "gym_contract"
        session.isDeload = true
        session.hidden = false
        return session
    }()

    static let minimalSession = WorkoutSessionModel(
        id: "session_contract_minimal",
        authorId: "user_contract_minimal",
        name: "Rest day",
        dateCreated: date("2026-10-13T08:00:00.000Z"),
        exercises: []
    )

    static let fullPrivateSettings = PrivateUserSettings(
        fcmToken: "fcm-token",
        socialPushLikes: false,
        socialPushComments: true,
        socialPushFollows: false,
        socialPushNudges: true,
        socialPushMentions: false,
        socialPushShares: true,
        reminderHour: 7,
        timezone: "Europe/London",
        socialPushStreakReminder: true,
        socialPushWeeklyDigest: false,
        weekStreak: 12,
        weekSessions: 3,
        weekGoal: 4,
        weekEndsAt: date("2026-10-18T23:00:00.000Z"),
        lastTrainedAt: date("2026-10-13T17:45:30.250Z"),
        socialPushChallenges: true,
        pushComeBackReminders: false,
        pushMealReminders: true,
        coachConsent: true,
        coachConsentAt: date("2026-09-01T12:00:00.500Z")
    )
}

private extension UserModel {
    func withUsername(_ handle: String) -> UserModel {
        var copy = self
        copy.username = handle
        return copy
    }
}

// MARK: - Tagged JSON <-> Firestore values

/// Converts between fixture JSON and the `[String: Any]` Firestore's coders read and write, and
/// compares the results strictly: a Bool is not an Int, and an Int is not a Double.
enum ContractJSON {
    static let timestampTag = "$timestamp"
    /// Tags a Double JSON cannot hold: `{"$double": "NaN"}`, `"Infinity"` or `"-Infinity"`. Only
    /// legacy inputs use it, for the values `NutrientMap` drops.
    static let doubleTag = "$double"

    enum ContractError: Error { case badTimestamp(String), unsupported(String) }

    /// Fixture JSON to Firestore values: each tagged timestamp becomes a `Timestamp`.
    static func firestore(_ json: [String: Any]) throws -> [String: Any] {
        try json.mapValues(firestoreValue)
    }

    private static func firestoreValue(_ json: Any) throws -> Any {
        if let map = json as? [String: Any] {
            if map.count == 1, let iso = map[timestampTag] as? String {
                let (seconds, nanos) = try timestampParts(iso)
                return Timestamp(seconds: seconds, nanoseconds: nanos)
            }
            if map.count == 1, let raw = map[doubleTag] as? String {
                guard ["NaN", "Infinity", "-Infinity"].contains(raw), let value = Double(raw) else {
                    throw ContractError.unsupported(raw)
                }
                return value
            }
            return try map.mapValues(firestoreValue)
        }
        if let array = json as? [Any] { return try array.map(firestoreValue) }
        return json
    }

    /// Firestore values to fixture JSON: each `Timestamp` becomes a tag, to the millisecond.
    static func tagged(_ firestore: [String: Any]) throws -> [String: Any] {
        try firestore.mapValues(taggedValue)
    }

    private static func taggedValue(_ value: Any) throws -> Any {
        switch value {
        case let timestamp as Timestamp: return [timestampTag: iso(timestamp)]
        // Firestore.Encoder passes a Date through; the SDK makes it a Timestamp on write.
        case let date as Date: return [timestampTag: iso(Timestamp(date: date))]
        case let map as [String: Any]: return try map.mapValues(taggedValue)
        case let array as [Any]: return try array.map(taggedValue)
        case is NSNull, is NSNumber, is String: return value
        default: throw ContractError.unsupported("\(type(of: value))")
        }
    }

    /// "2026-01-02T03:04:05.123Z" to whole seconds and nanoseconds, without passing through a Double.
    static func timestampParts(_ iso: String) throws -> (Int64, Int32) {
        let parts = iso.split(separator: ".", maxSplits: 1)
        guard iso.hasSuffix("Z"), parts.count == 2,
              let base = baseFormatter.date(from: String(parts[0]) + "Z") else { throw ContractError.badTimestamp(iso) }
        let fraction = parts[1].dropLast()
        guard fraction.count == 3, let millis = Int32(fraction) else { throw ContractError.badTimestamp(iso) }
        return (Int64(base.timeIntervalSince1970), millis * 1_000_000)
    }

    private static func iso(_ timestamp: Timestamp) -> String {
        var seconds = timestamp.seconds
        var millis = (Int64(timestamp.nanoseconds) + 500_000) / 1_000_000
        if millis == 1000 { seconds += 1; millis = 0 }
        let base = baseFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
        return String(base.dropLast()) + String(format: ".%03lldZ", millis)
    }

    private static let baseFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    /// A JSON value with its type kept, for strict equality.
    indirect enum Value: Equatable {
        case null, bool(Bool), int(Int64), double(Double), string(String), array([Value]), map([String: Value])
        /// Anything JSON cannot hold, named by type so it never compares equal to a real value.
        case other(String)

        init(_ any: Any) {
            switch any {
            case let map as [String: Any]: self = .map(map.mapValues(Value.init))
            case let array as [Any]: self = .array(array.map(Value.init))
            case let string as String: self = .string(string)
            case let number as NSNumber:
                if CFGetTypeID(number) == CFBooleanGetTypeID() {
                    self = .bool(number.boolValue)
                } else if number is NSDecimalNumber || ["f", "d"].contains(String(cString: number.objCType)) {
                    self = .double(number.doubleValue)
                } else {
                    self = .int(number.int64Value)
                }
            case is NSNull: self = .null
            default: self = .other(String(describing: type(of: any)))
            }
        }
    }
}
