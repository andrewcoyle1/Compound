//
//  NutritionParityTests.swift
//  CompoundUnitTests
//
//  The Flutter app's compound_maths package ports the nutrition rules: NutritionTargets and the
//  plan assembly in NutritionManager.computeDietPlan, TargetProposal, CheckInSchedule and the
//  macro header's remaining figure. CompoundUnitTests/Fixtures/nutrition-parity.json holds the
//  cases both sides check: this suite builds every case's input here, runs the real Swift on it
//  and requires the fixture to say the same, and app/packages/compound_maths/test/
//  nutrition_parity_test.dart runs the Dart on the same inputs.
//
//  After a deliberate change to the Swift, re-record with
//  `TEST_RUNNER_RECORD_PARITY=1 xcodebuild test … -only-testing:CompoundUnitTests/NutritionParityTests`
//  (xcodebuild hands the variable to the runner without its prefix) and port the change.
//
//  Dates are day keys read in UTC, so the cases hold in any time zone.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct NutritionParityTests {

    private static let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/nutrition-parity.json")

    @Test("Test The Nutrition Rules Match The Fixture")
    func testTheNutritionRulesMatchTheFixture() throws {
        let generated = try JSONSerialization.data(
            withJSONObject: Self.document(),
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        if ProcessInfo.processInfo.environment["RECORD_PARITY"] == "1" {
            try generated.write(to: Self.fixtureURL)
        }
        let actual = try JSONSerialization.jsonObject(with: generated)
        let expected = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.fixtureURL))
        let difference = Self.mismatch(actual, expected, path: "$")
        #expect(difference == nil, "\(difference ?? ""): re-record with TEST_RUNNER_RECORD_PARITY=1 and port the change")
    }

    static func document() -> [String: Any] {
        [
            "calorieFloor": calorieFloorCases(),
            "signedWeeklyChange": signedWeeklyChangeCases(),
            "goalTarget": goalTargetCases(),
            "referenceWeight": referenceWeightCases(),
            "proteinGrams": proteinGramsCases(),
            "macros": macrosCases(),
            "highDayIndices": (0...8).map { ["count": $0, "expected": NutritionTargets.highDayIndices(count: $0)] },
            "dailyCalories": dailyCaloriesCases(),
            "dietPlan": dietPlanCases(),
            "targetProposal": targetProposalCases(),
            "checkIn": checkInCases(),
            "macroRemaining": macroRemainingCases()
        ]
    }

    // MARK: - Comparison

    /// Equal JSON, numbers within a millionth. The first difference's path, or nil.
    static func mismatch(_ actual: Any, _ expected: Any, path: String) -> String? {
        switch (actual, expected) {
        case let (lhs as NSNumber, rhs as NSNumber):
            let tolerance = 1e-6 * max(abs(rhs.doubleValue), 1)
            return abs(lhs.doubleValue - rhs.doubleValue) <= tolerance ? nil : "\(path): \(lhs) != \(rhs)"
        case let (lhs as String, rhs as String):
            return lhs == rhs ? nil : "\(path): \(lhs) != \(rhs)"
        case (is NSNull, is NSNull):
            return nil
        case let (lhs as [Any], rhs as [Any]):
            guard lhs.count == rhs.count else { return "\(path): \(lhs.count) items, expected \(rhs.count)" }
            return zip(lhs, rhs).enumerated().lazy.compactMap { mismatch($1.0, $1.1, path: "\(path)[\($0)]") }.first
        case let (lhs as [String: Any], rhs as [String: Any]):
            guard Set(lhs.keys) == Set(rhs.keys) else { return "\(path): keys \(lhs.keys.sorted()) != \(rhs.keys.sorted())" }
            return rhs.keys.sorted().lazy.compactMap { key in lhs[key].flatMap { mismatch($0, rhs[key] ?? NSNull(), path: "\(path).\(key)") } }.first
        default:
            return "\(path): \(actual) != \(expected)"
        }
    }

    // MARK: - JSON helpers

    static func json(_ value: Any?) -> Any { value ?? NSNull() }

    static func json(_ macros: DailyMacroTarget) -> [String: Any] {
        ["calories": macros.calories, "proteinGrams": macros.proteinGrams, "carbGrams": macros.carbGrams, "fatGrams": macros.fatGrams]
    }

    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = utc
        formatter.timeZone = utc.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func date(_ dayKey: String) -> Date { dayKeyFormatter.date(from: dayKey) ?? .distantPast }
    static func dayKey(_ date: Date) -> String { dayKeyFormatter.string(from: date) }
    static func addDays(_ dayKey: String, _ days: Int) -> String {
        Self.dayKey(utc.date(byAdding: .day, value: days, to: date(dayKey)) ?? date(dayKey))
    }

    /// A goal as the fixture writes it, and the `WeightGoal` it stands for.
    static func goal(_ starting: Double, _ target: Double, _ weekly: Double, _ status: WeightGoal.GoalStatus = .active) -> WeightGoal {
        WeightGoal(
            userId: "user-1",
            objective: target < starting ? .loseWeight : (target > starting ? .gainWeight : .maintain),
            startingWeightKg: starting,
            targetWeightKg: target,
            weeklyChangeKg: weekly,
            createdAt: date("2026-01-01"),
            status: status
        )
    }

    static func json(_ goal: WeightGoal?) -> Any {
        guard let goal else { return NSNull() }
        return [
            "startingWeightKg": goal.startingWeightKg,
            "targetWeightKg": goal.targetWeightKg,
            "weeklyChangeKg": goal.weeklyChangeKg,
            "status": goal.status.rawValue
        ]
    }
}

// MARK: - NutritionTargets

extension NutritionParityTests {

    static func calorieFloorCases() -> [[String: Any]] {
        ([.male, .female, .preferNotToSay, nil] as [Gender?]).map { gender in
            ["gender": json(gender?.rawValue), "expected": CalorieFloor.standard.minimumValue(for: gender)]
        }
    }

    static func signedWeeklyChangeCases() -> [[String: Any]] {
        [goal(85, 78, 0.5), goal(70, 76, 0.3), goal(72, 72, 0.4), goal(85, 78, -0.5), goal(70, 76, -0.3)].map { goal in
            [
                "startingWeightKg": goal.startingWeightKg,
                "targetWeightKg": goal.targetWeightKg,
                "weeklyChangeKg": goal.weeklyChangeKg,
                "expected": goal.signedWeeklyChangeKg
            ]
        }
    }

    static func goalTargetCases() -> [[String: Any]] {
        let goals: [WeightGoal?] = [
            nil, goal(85, 78, 0.5), goal(85, 70, 1.0), goal(70, 76, 0.25), goal(72, 72, 0),
            goal(85, 78, 0.5, .paused), goal(85, 78, 0.5, .completed), goal(85, 78, 0.5, .abandoned)
        ]
        return [2500.0, 1800, 1400].flatMap { expenditure in
            goals.map { goal in
                [
                    "expenditureKcal": expenditure,
                    "goal": json(goal),
                    "expected": NutritionManager.goalTarget(expenditureKcal: expenditure, goal: goal)
                ]
            }
        }
    }

    static func referenceWeightCases() -> [[String: Any]] {
        // Weight, height, goal weight.
        let inputs: [[Double?]] = [
            [80, 180, nil], [130, 175, nil], [130, 175, 110], [130, 175, 80], [130, 175, 150], [130, nil, nil],
            [130, 0, nil], [130, -5, nil], [91.875, 175, nil], [92, 175, nil], [130, 175, 0], [130, 175, -10],
            [60, 150, 100], [200, 190, nil], [45, 160, 70]
        ]
        return inputs.map { row in
            let (weight, height, goalWeight) = (row[0] ?? 0, row[1], row[2])
            return [
                "weightKg": weight,
                "heightCm": json(height),
                "goalWeightKg": json(goalWeight),
                "expected": NutritionTargets.referenceWeightKg(weightKg: weight, heightCm: height, goalWeightKg: goalWeight)
            ]
        }
    }

    static func proteinGramsCases() -> [[String: Any]] {
        ProteinIntake.allCases.flatMap { intake in
            [70.0, 91.875].flatMap { reference in
                ([nil, 30, 64, 65, 80] as [Int?]).map { age in
                    [
                        "intake": intake.rawValue,
                        "referenceWeightKg": reference,
                        "ageYears": json(age),
                        "expected": NutritionTargets.proteinGrams(intake: intake, referenceWeightKg: reference, ageYears: age)
                    ]
                }
            }
        }
    }

    static func macrosCases() -> [[String: Any]] {
        PreferredDiet.allCases.flatMap { diet in
            [800.0, 1200, 2000, 3000.4].flatMap { calories in
                [150.0, 250.5].flatMap { protein in
                    [55.0, 120].map { reference in
                        [
                            "calories": calories,
                            "proteinGrams": protein,
                            "diet": diet.rawValue,
                            "referenceWeightKg": reference,
                            "expected": json(NutritionTargets.macros(
                                calories: calories, proteinGrams: protein, diet: diet, referenceWeightKg: reference
                            ))
                        ]
                    }
                }
            }
        }
    }

    static func dailyCaloriesCases() -> [[String: Any]] {
        let inputs: [(Double, Double)] = [(2000, 1500), (1400, 1500), (1600, 1500), (2750.5, 1200)]
        return inputs.flatMap { target, floor in
            CalorieDistribution.allCases.flatMap { distribution in
                (-1...8).map { days in
                    [
                        "target": target,
                        "floor": floor,
                        "distribution": distribution.rawValue,
                        "trainingDaysPerWeek": days,
                        "expected": NutritionTargets.dailyCalories(
                            target: target, floor: floor, distribution: distribution, trainingDaysPerWeek: days
                        )
                    ]
                }
            }
        }
    }

    static func macroRemainingCases() -> [[String: Any]] {
        [(0.0, 2000.0), (1500, 2000), (2000, 2000), (2020, 2000), (35.5, 0), (10, -5)].flatMap { total, target in
            [true, false].map { overages in
                [
                    "total": total,
                    "target": target,
                    "showOverages": overages,
                    "expected": MacroHeader.remaining(total: total, target: target, showOverages: overages)
                ]
            }
        }
    }
}
