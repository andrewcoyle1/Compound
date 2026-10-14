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
//  millisecond). Per model:
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

    private struct Contract {
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

    private static func contract<T: Codable>(
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
            )
        ]
    }

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
        let enums: [String: [String]] = [
            "ActivityLevel": ActivityLevel.allCases.map(\.rawValue),
            "CardioFitnessLevel": CardioFitnessLevel.allCases.map(\.rawValue),
            "DistanceUnitPreference": DistanceUnitPreference.allCases.map(\.rawValue),
            "ExerciseFrequency": ExerciseFrequency.allCases.map(\.rawValue),
            "Gender": Gender.allCases.map(\.rawValue),
            "LengthUnitPreference": LengthUnitPreference.allCases.map(\.rawValue),
            "WeightUnitPreference": weightUnits.map(\.rawValue)
        ]
        let url = Self.root.appendingPathComponent("enums.json")
        if ProcessInfo.processInfo.environment["RECORD_CONTRACTS"] == "1" { try Self.write(enums, to: url) }
        let fixture = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: [String]])
        #expect(fixture == enums)
    }

    // MARK: - Fixture files

    private static let root = URL(fileURLWithPath: #filePath)
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

    private static func taggedFixture(_ directory: String, _ name: String) throws -> [String: Any] {
        let data = try Data(contentsOf: fixtureURL(directory, name))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func firestoreDocument(_ directory: String, _ name: String) throws -> [String: Any] {
        try ContractJSON.firestore(try taggedFixture(directory, name))
    }

    private static func write(_ object: Any, to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // JSONSerialization writes `"key" : value`; the usual spelling keeps hand-written fixtures alike.
        let text = (String(bytes: data, encoding: .utf8) ?? "").replacingOccurrences(of: "\" : ", with: "\": ")
        try Data((text + "\n").utf8).write(to: url)
    }
}

// MARK: - Fixed samples

/// What `RECORD_CONTRACTS=1` writes. Fixed values, never `Date()`, so a re-record changes only
/// what the model changed. Doubles are deliberately not whole numbers (JSON would write 172.0 as
/// 172, which reads back as an integer) and are exact in binary, so the JSON stays short.
private enum Samples {
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
