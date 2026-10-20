//
//  NutritionParityTests+Cases.swift
//  CompoundUnitTests
//
//  The plan assembly, target proposal and check-in cases of nutrition-parity.json.
//

import Foundation
@testable import Compound

// MARK: - computeDietPlan

extension NutritionParityTests {

    private struct PlanInput {
        var expenditureKcal: Double = 2500
        var targetKcal: Double?
        var goal: WeightGoal?
        var gender: Gender? = .male
        var weightKg: Double? = 80
        var heightCm: Double? = 180
        var ageYears: Int?
        var diet: PreferredDiet = .balanced
        var distribution: CalorieDistribution = .even
        var protein: ProteinIntake = .moderate
        var trainingDaysPerWeek = 0
    }

    private static let planInputs: [PlanInput] = [
        PlanInput(),
        PlanInput(goal: goal(65, 58, 0.5), gender: .female, weightKg: 65, heightCm: 165, ageYears: 34, diet: .keto, distribution: .varied, trainingDaysPerWeek: 4),
        PlanInput(expenditureKcal: 3100, goal: goal(130, 110, 0.75), weightKg: 130, heightCm: 175, diet: .lowCarb, protein: .high),
        PlanInput(expenditureKcal: 3100, goal: goal(130, 80, 0.75), weightKg: 130, heightCm: 175, diet: .lowFat, distribution: .varied, protein: .veryHigh, trainingDaysPerWeek: 3),
        PlanInput(expenditureKcal: 3100, goal: goal(130, 110, 0.75, .paused), weightKg: 130, heightCm: 175),
        PlanInput(expenditureKcal: 2000, gender: nil, weightKg: nil, heightCm: nil),
        PlanInput(expenditureKcal: 1900, gender: .preferNotToSay, weightKg: 600, heightCm: 200, ageYears: 70, protein: .low),
        PlanInput(expenditureKcal: 2200, targetKcal: 900, gender: .female, weightKg: 55, heightCm: 160),
        PlanInput(expenditureKcal: 2200, targetKcal: 2600, goal: goal(70, 76, 0.25), weightKg: 70, heightCm: 178, distribution: .varied, trainingDaysPerWeek: 7),
        PlanInput(expenditureKcal: 1600, goal: goal(90, 70, 1.0), gender: .female, weightKg: 90, heightCm: 170, ageYears: 66, diet: .keto, distribution: .varied, trainingDaysPerWeek: 6),
        PlanInput(expenditureKcal: 2800, goal: goal(75, 82, 0.4), weightKg: 20, heightCm: 182, diet: .lowCarb, distribution: .varied, trainingDaysPerWeek: 2),
        PlanInput(expenditureKcal: 2400, weightKg: 100, heightCm: 0, distribution: .varied, protein: .high, trainingDaysPerWeek: 5)
    ]

    static func dietPlanCases() -> [[String: Any]] {
        let manager = NutritionManager(dietPlanSyncEngine: TestManagers.documentEngine(nil as DietPlan?, key: "nutrition-parity"))
        return planInputs.map { input in
            // A birthday a day short of `ageYears` years ago, so the age the manager counts from
            // today is the one the fixture records, whenever the suite runs.
            let birthDate = input.ageYears.flatMap { age in
                Calendar.current.date(byAdding: DateComponents(year: -age, day: 1), to: Date())
            }
            let user = UserModel(
                userId: "user-1",
                submittedDateOfBirth: birthDate,
                submittedGender: input.gender,
                submittedHeightCentimeters: input.heightCm,
                submittedWeightKilograms: input.weightKg
            )
            let delegate = DietPlanDelegate(
                preferredDiet: input.diet,
                calorieFloor: .standard,
                calorieDistribution: input.distribution,
                proteinIntake: input.protein,
                isFromSettings: false
            )
            let plan = manager.computeDietPlan(
                user: user,
                delegate: delegate,
                mesocycle: input.trainingDaysPerWeek > 0 ? mesocycle(trainingDays: input.trainingDaysPerWeek) : nil,
                expenditureKcal: input.expenditureKcal,
                targetKcal: input.targetKcal,
                goal: input.goal
            )
            return [
                "expenditureKcal": input.expenditureKcal,
                "targetKcal": json(input.targetKcal),
                "goal": json(input.goal),
                "gender": json(input.gender?.rawValue),
                "weightKg": json(input.weightKg),
                "heightCm": json(input.heightCm),
                "ageYears": json(input.ageYears),
                "diet": input.diet.rawValue,
                "distribution": input.distribution.rawValue,
                "protein": input.protein.rawValue,
                "trainingDaysPerWeek": input.trainingDaysPerWeek,
                "expected": plan.days.map { json($0) }
            ]
        }
    }

    private static func mesocycle(trainingDays: Int) -> Mesocycle {
        Mesocycle(
            id: "program-1",
            authorId: "user-1",
            name: "Upper/Lower",
            icon: "flag",
            colour: "#FF0000",
            workoutTemplates: (0..<trainingDays).map { index in
                WorkoutTemplateModel(
                    id: "day-\(index)",
                    authorId: "user-1",
                    name: "Day \(index)",
                    exercises: [WorkoutTemplateExercise(exercise: ExerciseModel.mock, setRestTimers: false)]
                )
            }
        )
    }
}

// MARK: - TargetProposal

extension NutritionParityTests {

    private struct ProposalInput {
        var kcal: Double = 2800
        var source: ExpenditureEstimate.Source = .adaptive
        var isProvisional = false
        var weeklyTrendChangeKg: Double?
        var sdKcal: Double? = 100
        var recentIntakeKcal: Double?
        var planDays: [Double]? = Array(repeating: 2000, count: 7)
        var planAgeDays = 30
        var goal: WeightGoal?
        var mode: ExpenditureCalculationMode = .dynamic
        var kcalPerKg = EnergyDensity.conventionalKcalPerKg
        var gender: Gender?
        var dismissedKcal: Double?
    }

    private static let proposalDay = "2026-06-15"

    private static func flat(_ kcal: Double) -> [Double] { Array(repeating: kcal, count: 7) }

    private static let proposalInputs: [ProposalInput] = [
        ProposalInput(planDays: nil),
        ProposalInput(planDays: []),
        ProposalInput(source: .prior, isProvisional: true),
        ProposalInput(isProvisional: true),
        ProposalInput(source: .prior),
        ProposalInput(source: .fixed),
        ProposalInput(mode: .fixed),
        ProposalInput(kcal: 2040),
        ProposalInput(kcal: 2050),
        ProposalInput(kcal: 2051),
        ProposalInput(kcal: 1949),
        ProposalInput(kcal: 2050, sdKcal: 50),
        ProposalInput(kcal: 2051, sdKcal: 50),
        ProposalInput(kcal: 1949, sdKcal: 30),
        ProposalInput(kcal: 1950, sdKcal: nil),
        ProposalInput(kcal: 2120),
        ProposalInput(kcal: 2120, goal: goal(85, 78, 0.5, .paused)),
        ProposalInput(planDays: flat(2140), goal: goal(85, 78, 0.5)),
        ProposalInput(planDays: flat(2240), goal: goal(85, 78, 0.5), kcalPerKg: 6300),
        ProposalInput(weeklyTrendChangeKg: -0.2, planDays: flat(2140), goal: goal(85, 78, 0.5)),
        ProposalInput(kcal: 2120, sdKcal: 150),
        ProposalInput(kcal: 2151, sdKcal: 150),
        ProposalInput(kcal: 2060, sdKcal: nil),
        ProposalInput(kcal: 2200, planAgeDays: 6),
        ProposalInput(kcal: 2200, planAgeDays: 7),
        ProposalInput(kcal: 2200, planAgeDays: -3),
        ProposalInput(kcal: 2500, weeklyTrendChangeKg: -0.1, recentIntakeKcal: 2500, planDays: flat(2150), goal: goal(85, 78, 0.5)),
        ProposalInput(kcal: 2500, weeklyTrendChangeKg: -0.1, recentIntakeKcal: 2500, planDays: flat(2150), planAgeDays: 2, goal: goal(85, 78, 0.5)),
        ProposalInput(kcal: 2500, weeklyTrendChangeKg: -0.1, recentIntakeKcal: 2200, planDays: flat(2150), goal: goal(85, 78, 0.5)),
        ProposalInput(kcal: 2500, weeklyTrendChangeKg: -0.1, recentIntakeKcal: 2365, planDays: flat(2150), goal: goal(85, 78, 0.5)),
        ProposalInput(kcal: 2500, weeklyTrendChangeKg: -0.1, recentIntakeKcal: 2366, planDays: flat(2150), goal: goal(85, 78, 0.5)),
        ProposalInput(kcal: 2500, weeklyTrendChangeKg: -0.5, recentIntakeKcal: 2500, planDays: flat(2150), goal: goal(85, 78, 0.5)),
        ProposalInput(kcal: 2500, weeklyTrendChangeKg: nil, recentIntakeKcal: 2500, planDays: flat(2150), goal: goal(85, 78, 0.5)),
        ProposalInput(kcal: 2500, weeklyTrendChangeKg: 0.2, recentIntakeKcal: 2600, planDays: flat(2150)),
        ProposalInput(kcal: 2900, weeklyTrendChangeKg: 0.2, recentIntakeKcal: 2600, planDays: flat(2150)),
        ProposalInput(kcal: 1800, planDays: flat(2400)),
        ProposalInput(kcal: 1400, planDays: flat(1640), goal: goal(85, 70, 1.0), gender: .male),
        ProposalInput(kcal: 1400, planDays: flat(1640), goal: goal(85, 70, 1.0), gender: .female),
        ProposalInput(kcal: 1400, planDays: flat(1640), goal: goal(85, 70, 1.0), gender: .preferNotToSay),
        ProposalInput(kcal: 1400, planDays: flat(1640), goal: goal(85, 70, 1.0)),
        ProposalInput(kcal: 2600, planDays: [2200, 2200, 1900, 2200, 1900, 2200, 1900], goal: goal(70, 76, 0.25)),
        ProposalInput(dismissedKcal: 2140),
        ProposalInput(dismissedKcal: 2150),
        ProposalInput(dismissedKcal: 2100),
        ProposalInput(dismissedKcal: 2050),
        ProposalInput(dismissedKcal: 2199.9)
    ]

    private static func estimate(_ input: ProposalInput) -> ExpenditureEstimate {
        ExpenditureEstimate(
            day: date(proposalDay),
            kcal: input.kcal,
            source: input.source,
            isProvisional: input.isProvisional,
            trendWeightKg: 80,
            weeklyTrendChangeKg: input.weeklyTrendChangeKg,
            loggedDays: 24,
            weighInCount: 20,
            windowDays: 28,
            stepAdjustmentKcal: 0,
            sdKcal: input.sdKcal,
            recentIntakeKcal: input.recentIntakeKcal
        )
    }

    private static func plan(_ input: ProposalInput, createdDay: String) -> DietPlan? {
        input.planDays.map { days in
            DietPlan(
                planId: "plan-1",
                userId: "user-1",
                createdAt: date(createdDay).addingTimeInterval(9 * 3600),
                tdeeEstimate: 2500,
                preferredDiet: PreferredDiet.balanced.rawValue,
                calorieFloor: CalorieFloor.standard.rawValue,
                trainingType: "moderate",
                calorieDistribution: CalorieDistribution.even.rawValue,
                proteinIntake: ProteinIntake.moderate.rawValue,
                days: days.map { DailyMacroTarget(calories: $0, proteinGrams: 150, carbGrams: 200, fatGrams: 70) }
            )
        }
    }

    static func targetProposalCases() -> [[String: Any]] {
        proposalInputs.map { input in
            let estimate = estimate(input)
            let createdDay = addDays(proposalDay, -input.planAgeDays)
            let plan = plan(input, createdDay: createdDay)
            var settings = NutritionStrategySettings(authorId: "user-1")
            settings.calculationMode = input.mode
            let outcome = TargetProposal.evaluate(
                estimate: estimate, plan: plan, goal: input.goal, settings: settings,
                kcalPerKg: input.kcalPerKg, gender: input.gender, calendar: utc
            )
            let shown = TargetProposal.make(
                estimate: estimate, plan: plan, goal: input.goal, settings: settings, dismissedKcal: input.dismissedKcal,
                kcalPerKg: input.kcalPerKg, gender: input.gender, calendar: utc
            )
            return [
                "estimate": [
                    "day": proposalDay,
                    "kcal": input.kcal,
                    "source": input.source.rawValue,
                    "isProvisional": input.isProvisional,
                    "weeklyTrendChangeKg": json(input.weeklyTrendChangeKg),
                    "sdKcal": json(input.sdKcal),
                    "recentIntakeKcal": json(input.recentIntakeKcal)
                ],
                "plan": json(input.planDays.map { ["dayCalories": $0, "createdDay": createdDay] }),
                "goal": json(input.goal),
                "calculationMode": input.mode.rawValue,
                "kcalPerKg": input.kcalPerKg,
                "gender": json(input.gender?.rawValue),
                "dismissedKcal": json(input.dismissedKcal),
                "expected": ["outcome": json(outcome), "shownProposedTargetKcal": json(shown?.proposedTargetKcal)]
            ]
        }
    }

    private static func json(_ outcome: TargetProposal.Outcome) -> Any {
        switch outcome {
        case .none:
            return NSNull()
        case .propose(let proposal):
            return [
                "kind": "proposal",
                "expenditureKcal": proposal.expenditureKcal,
                "currentTargetKcal": proposal.currentTargetKcal,
                "proposedTargetKcal": proposal.proposedTargetKcal,
                "weeklyTrendChangeKg": json(proposal.weeklyTrendChangeKg),
                "goalWeeklyChangeKg": json(proposal.goalWeeklyChangeKg)
            ]
        case .adherence(let note):
            return [
                "kind": "adherence",
                "targetKcal": note.targetKcal,
                "recentIntakeKcal": note.recentIntakeKcal,
                "weeklyTrendChangeKg": note.weeklyTrendChangeKg,
                "goalWeeklyChangeKg": json(note.goalWeeklyChangeKg)
            ]
        }
    }
}

// MARK: - CheckInSchedule

extension NutritionParityTests {

    /// Monday 21 September 2026, the start of an ISO week.
    private static let monday = "2026-09-21"

    private struct CheckInInput {
        let today: String
        let weekday: Int
        var completed: String?
        var skipped: String?
        var breakDays: (start: String, end: String?)?
    }

    private static var checkInInputs: [CheckInInput] {
        let lastWeek = addDays(monday, -7)
        var inputs: [CheckInInput] = []
        for weekday in 1...7 {
            for offset in -1...13 {
                let today = addDays(monday, offset)
                inputs.append(CheckInInput(today: today, weekday: weekday))
                inputs.append(CheckInInput(today: today, weekday: weekday, completed: monday))
                inputs.append(CheckInInput(today: today, weekday: weekday, skipped: monday))
                inputs.append(CheckInInput(today: today, weekday: weekday, completed: lastWeek, skipped: lastWeek))
            }
        }
        let breaks: [(start: String, end: String?)] = [
            (addDays(monday, -2), nil), (monday, nil), (addDays(monday, 1), nil),
            (addDays(monday, -5), addDays(monday, -1)), (addDays(monday, -5), addDays(monday, 3))
        ]
        for loggingBreak in breaks {
            for offset in [0, 2] {
                inputs.append(CheckInInput(today: addDays(monday, offset), weekday: 2, breakDays: loggingBreak))
            }
        }
        return inputs
    }

    static func checkInCases() -> [[String: Any]] {
        checkInInputs.map { input in
            var settings = NutritionStrategySettings(authorId: "user-1")
            settings.checkInWeekday = input.weekday
            let record = input.completed == nil && input.skipped == nil ? nil : CheckInRecord(
                authorId: "user-1",
                lastCompletedWeekStart: input.completed.map(date),
                lastSkippedWeekStart: input.skipped.map(date)
            )
            let loggingBreak = input.breakDays.map { days in
                LoggingBreak(authorId: "user-1", startDate: date(days.start), endDate: days.end.map(date))
            }
            let state = CheckInSchedule.state(
                today: date(input.today), settings: settings, record: record, break: loggingBreak, calendar: utc
            )
            let expected: [String: Any]
            switch state {
            case .notDue: expected = ["state": "notDue", "dueWeekStart": NSNull()]
            case .inBreak: expected = ["state": "inBreak", "dueWeekStart": NSNull()]
            case .due(let weekStart): expected = ["state": "due", "dueWeekStart": dayKey(weekStart)]
            }
            return [
                "today": input.today,
                "checkInWeekday": input.weekday,
                "lastCompletedWeekStart": json(input.completed),
                "lastSkippedWeekStart": json(input.skipped),
                "loggingBreak": json(input.breakDays.map { ["startDay": $0.start, "endDay": json($0.end)] }),
                "expected": expected.merging(
                    ["weekStart": dayKey(CheckInSchedule.weekStart(for: date(input.today), calendar: utc))]
                ) { $1 }
            ]
        }
    }
}
