//
//  CoachParityTests.swift
//  CompoundUnitTests
//
//  The coach's server answers with figures the app computes: expenditure, the weight trend,
//  estimated one-rep maxes and weekly sets per muscle. functions/coach-maths.js is a port of the
//  Swift, and CompoundUnitTests/Fixtures/coach-parity.json holds the cases both check. This side
//  computes each case with the real Swift and requires the fixture's expected values, so a change
//  to the Swift that the port has not followed fails here, and one to the port fails in node.
//
//  Every date in the fixture is a day key, read with `Date(dayKey:)` and `Calendar.current`, so the
//  cases hold in any time zone the tests run in.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct CoachParityTests {

    private static let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/coach-parity.json")

    private func fixture() throws -> [String: Any] {
        let data = try Data(contentsOf: Self.fixtureURL)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func cases(_ key: String) throws -> [[String: Any]] {
        try #require(try fixture()[key] as? [[String: Any]])
    }

    // MARK: - The cases

    @Test("Test The Expenditure Engine Matches The Fixture")
    func testExpenditureEngine() throws {
        for testCase in try cases("expenditureEngine") {
            expectMatch(Self.expenditureEngine(testCase), testCase["expected"], testCase)
        }
    }

    @Test("Test The Expenditure Samples Match The Fixture")
    func testExpenditureSamples() throws {
        for testCase in try cases("expenditureSamples") {
            expectMatch(Self.expenditureSamples(testCase), testCase["expected"], testCase)
        }
    }

    @Test("Test The Formula Expenditure Matches The Fixture")
    func testTDEE() throws {
        for testCase in try cases("tdee") {
            expectMatch(Self.tdee(testCase), testCase["expected"], testCase)
        }
    }

    @Test("Test The Weight Trend Matches The Fixture")
    func testWeightTrend() throws {
        for testCase in try cases("weightTrend") {
            expectMatch(Self.weightTrend(testCase), testCase["expected"], testCase)
        }
    }

    @Test("Test Estimated One Rep Maxes Match The Fixture")
    func testOneRepMax() throws {
        for testCase in try cases("oneRepMax") {
            expectMatch(Self.oneRepMax(testCase), testCase["expected"], testCase)
        }
    }

    @Test("Test Weekly Sets Per Muscle Match The Fixture")
    func testWeeklyMuscleSets() throws {
        for testCase in try cases("weeklyMuscleSets") {
            expectMatch(Self.weeklyMuscleSets(testCase), testCase["expected"], testCase)
        }
    }

    @Test("Test Paired Set Counts Match The Fixture")
    func testPairedSetCount() throws {
        for testCase in try cases("pairedSetCount") {
            expectMatch(Self.pairedSetCount(testCase), testCase["expected"], testCase)
        }
    }

    // MARK: - Comparing

    private func expectMatch(_ actual: Any, _ expected: Any?, _ testCase: [String: Any]) {
        let name = testCase["name"] as? String ?? "?"
        #expect(Self.matches(actual, expected ?? NSNull()), "\(name): Swift gives \(actual)")
    }

    /// Equal JSON values, numbers within a millionth: the two languages round the last bit apart.
    static func matches(_ lhs: Any, _ rhs: Any) -> Bool {
        switch (lhs, rhs) {
        case (is NSNull, is NSNull): return true
        case let (left as [String: Any], right as [String: Any]):
            return Set(left.keys) == Set(right.keys) && left.allSatisfy { key, value in right[key].map { matches(value, $0) } ?? false }
        case let (left as [Any], right as [Any]):
            return left.count == right.count && zip(left, right).allSatisfy { matches($0, $1) }
        case let (left as String, right as String): return left == right
        case let (left as NSNumber, right as NSNumber):
            if CFGetTypeID(left) == CFBooleanGetTypeID() || CFGetTypeID(right) == CFBooleanGetTypeID() {
                return left.boolValue == right.boolValue
            }
            return abs(left.doubleValue - right.doubleValue) <= 1e-6 * max(1, abs(right.doubleValue))
        default: return false
        }
    }

    // MARK: - Running the Swift

    private static func day(_ key: Any?) -> Date {
        // Safe: every day key in the fixture is a valid yyyy-MM-dd.
        Date(dayKey: key as? String ?? "")!
    }

    private static func noon(_ key: Any?) -> Date { day(key).addingTimeInterval(12 * 3600) }

    private static func json(_ value: Double?) -> Any { value.map { $0 as Any } ?? NSNull() }
    private static func json(_ value: Int?) -> Any { value.map { $0 as Any } ?? NSNull() }

    static func expenditureEngine(_ testCase: [String: Any]) -> Any {
        let samples = (testCase["samples"] as? [[String: Any]] ?? []).map { sample in
            DailySample(
                day: day(sample["day"]),
                intakeKcal: sample["intakeKcal"] as? Double,
                weightKg: sample["weightKg"] as? Double,
                steps: sample["steps"] as? Int,
                isExcluded: sample["isExcluded"] as? Bool ?? false
            )
        }
        let settingsJSON = testCase["settings"] as? [String: Any] ?? [:]
        var settings = NutritionStrategySettings(authorId: "parity")
        settings.calculationMode = ExpenditureCalculationMode(rawValue: settingsJSON["calculationMode"] as? String ?? "") ?? .dynamic
        settings.calculationStartDate = (settingsJSON["calculationStartDay"] as? String).map { day($0) }
        settings.stepInformedUpdates = settingsJSON["stepInformedUpdates"] as? Bool ?? false

        let history = ExpenditureEngine().history(
            samples: samples,
            priorKcal: testCase["priorKcal"] as? Double ?? 0,
            settings: settings,
            today: noon(testCase["today"]),
            calendar: .current
        )
        return history.map { estimate -> [String: Any] in
            [
                "day": estimate.day.dayKey,
                "kcal": estimate.kcal,
                "source": estimate.source.rawValue,
                "isProvisional": estimate.isProvisional,
                "trendWeightKg": json(estimate.trendWeightKg),
                "weeklyTrendChangeKg": json(estimate.weeklyTrendChangeKg),
                "loggedDays": estimate.loggedDays,
                "weighInCount": estimate.weighInCount,
                "windowDays": estimate.windowDays,
                "stepAdjustmentKcal": estimate.stepAdjustmentKcal
            ]
        }
    }

    private static func mealLogs(_ testCase: [String: Any]) -> [MealLogModel] {
        (testCase["meals"] as? [[String: Any]] ?? []).enumerated().map { index, meal in
            let calories = meal["calories"] as? Double ?? 0
            let item = MealItemModel(
                itemId: "item-\(index)", sourceType: .ingredient, sourceId: "x", displayName: "Food",
                amount: 1, unit: "serving", nutrients: NutrientMap([.calories: calories])
            )
            let key = meal["dayKey"] as? String ?? ""
            return MealLogModel(authorId: "parity", dayKey: key, date: noon(key), items: [item])
        }
    }

    static func expenditureSamples(_ testCase: [String: Any]) -> Any {
        let meals = mealLogs(testCase)
        let measurements = (testCase["measurements"] as? [[String: Any]] ?? []).map { entry in
            let date = noon(entry["day"])
            return BodyMeasurementEntry(
                authorId: "parity", weightKg: entry["weightKg"] as? Double, date: date,
                deletedAt: entry["deleted"] as? Bool == true ? date : nil
            )
        }
        let steps = (testCase["steps"] as? [[String: Any]] ?? []).map { record in
            let date = noon(record["day"])
            return StepsModel(
                authorId: "parity", number: record["number"] as? Int ?? 0, date: date,
                deletedAt: record["deleted"] as? Bool == true ? date : nil
            )
        }
        let annotations = (testCase["annotations"] as? [[String: Any]] ?? []).map { annotation in
            NutritionDayAnnotation(
                dayKey: annotation["dayKey"] as? String ?? "",
                authorId: "parity",
                isPartiallyLogged: annotation["isPartiallyLogged"] as? Bool ?? false,
                isFastingDay: annotation["isFastingDay"] as? Bool ?? false
            )
        }
        let loggingBreak = (testCase["loggingBreak"] as? [String: Any]).map { json in
            LoggingBreak(authorId: "parity", startDate: day(json["startDay"]), endDate: (json["endDay"] as? String).map { day($0) })
        }

        return ExpenditureSampleBuilder.samples(
            mealLogs: meals,
            measurements: measurements,
            steps: steps,
            annotations: annotations,
            loggingBreak: loggingBreak,
            today: noon(testCase["today"]),
            calendar: .current
        ).map { sample -> [String: Any] in
            [
                "day": sample.day.dayKey,
                "intakeKcal": json(sample.intakeKcal),
                "weightKg": json(sample.weightKg),
                "steps": json(sample.steps),
                "isExcluded": sample.isExcluded
            ]
        }
    }

    static func tdee(_ testCase: [String: Any]) -> Any {
        let profile = testCase["profile"] as? [String: Any] ?? [:]
        let user = UserModel(
            userId: "parity",
            submittedGender: (profile["gender"] as? String).flatMap(Gender.init(rawValue:)),
            submittedHeightCentimeters: profile["heightCm"] as? Double,
            submittedWeightKilograms: profile["weightKg"] as? Double,
            submittedExerciseFrequency: (profile["exerciseFrequency"] as? String).flatMap(ExerciseFrequency.init(rawValue:)),
            submittedDailyActivityLevel: (profile["activity"] as? String).flatMap(ActivityLevel.init(rawValue:))
        )
        return TestManagers.nutritionManager().estimateTDEE(
            user: user,
            equation: BMREquation(rawValue: testCase["equation"] as? String ?? "") ?? .mifflinStJeor,
            bodyFatPercentage: testCase["bodyFatPercentage"] as? Double
        )
    }

    static func weightTrend(_ testCase: [String: Any]) -> Any {
        let values = testCase["values"] as? [Double] ?? []
        let data = values.enumerated().map { (date: Date(timeIntervalSince1970: Double($0.offset) * 86_400), value: $0.element) }
        return WeightTrendCalculator.exponentialMovingAverage(data: data).map(\.value)
    }

    private static func sessions(_ testCase: [String: Any]) -> [WorkoutSessionModel] {
        (testCase["sessions"] as? [[String: Any]] ?? []).enumerated().map { index, json in
            let date = noon(json["day"]).addingTimeInterval(json["order"] as? Double ?? 0)
            let exercises = (json["exercises"] as? [[String: Any]] ?? []).enumerated().map { position, exercise in
                WorkoutExerciseModel(
                    id: "e\(index)-\(position)", authorId: "parity", templateId: exercise["templateId"] as? String ?? "",
                    name: exercise["name"] as? String ?? "", trackingMode: .weightReps, index: position,
                    sets: (exercise["sets"] as? [[String: Any]] ?? []).enumerated().map { setIndex, set in
                        WorkoutSetModel(
                            id: "s\(index)-\(position)-\(setIndex)", authorId: "parity", index: setIndex,
                            reps: set["reps"] as? Int, weightKg: set["weightKg"] as? Double,
                            side: (set["side"] as? String).flatMap(SetSide.init(rawValue:)),
                            parentSetId: set["parentSetId"] as? String,
                            isWarmup: set["isWarmup"] as? Bool ?? false,
                            completedAt: set["completed"] as? Bool == true ? date : nil, dateCreated: date
                        )
                    }
                )
            }
            return WorkoutSessionModel(id: "session-\(index)", authorId: "parity", name: "Session", dateCreated: date, endedAt: date, exercises: exercises)
        }
    }

    static func oneRepMax(_ testCase: [String: Any]) -> Any {
        ExerciseOneRMAggregator.aggregate(sessions: sessions(testCase)).mapValues { aggregate -> [String: Any] in
            [
                "name": aggregate.name,
                "latest1RM": aggregate.latest1RM,
                "last7Workouts": aggregate.last7Workouts.map { ["day": $0.date.dayKey, "value": $0.value] as [String: Any] }
            ]
        }
    }

    static func weeklyMuscleSets(_ testCase: [String: Any]) -> Any {
        let templatesJSON = testCase["templates"] as? [String: [String: String]] ?? [:]
        let templates = templatesJSON.mapValues { groups in
            ExerciseModel(
                authorId: "parity", name: "x", trackableMetrics: [], type: nil, laterality: nil,
                muscleGroups: Dictionary(uniqueKeysWithValues: groups.compactMap { key, value in
                    Muscles(rawValue: key).flatMap { muscle in MuscleTargetType(rawValue: value).map { (muscle, $0) } }
                }),
                isBodyweight: false, rangeOfMotion: 0, stability: 0, bodyWeightContribution: 0, alternateNames: []
            )
        }
        let weekly = MuscleVolume.weeklySets(
            sessions: sessions(testCase),
            templates: templates,
            calendar: .current,
            endDate: noon(testCase["endDay"]),
            weeks: testCase["weeks"] as? Int ?? 12
        )
        return Dictionary(uniqueKeysWithValues: weekly.map { ($0.key.rawValue, $0.value) })
    }

    static func pairedSetCount(_ testCase: [String: Any]) -> Any {
        let sides = testCase["sides"] as? [Any] ?? []
        return sides.enumerated().map { index, side in
            WorkoutSetModel(
                id: "\(index)", authorId: "parity", index: index,
                side: (side as? String).flatMap(SetSide.init(rawValue:)),
                isWarmup: false, dateCreated: Date(timeIntervalSince1970: 0)
            )
        }.pairedSetCount
    }
}
