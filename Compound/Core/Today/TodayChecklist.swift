//
//  TodayChecklist.swift
//  Compound
//
//  The day as a list of things to get done: train, eat to target, weigh in, walk. Today's job is
//  to run the day and then close it, so each item knows whether it is done, and the day is
//  complete when every item that applies is.
//

import Foundation

struct TodayChecklist: Equatable {

    enum Kind: String, CaseIterable {
        case training, nutrition, weighIn, steps
    }

    struct Item: Equatable, Identifiable {
        let kind: Kind
        let isDone: Bool
        let detail: String
        var id: Kind { kind }
    }

    let items: [Item]

    var doneCount: Int { items.filter(\.isDone).count }
    var isComplete: Bool { !items.isEmpty && items.allSatisfy(\.isDone) }

    // MARK: - Inputs

    enum Training: Equatable {
        /// A workout finished today.
        case done(name: String)
        /// Today's plan is a rest day: taking it is the job done.
        case restDay
        case planned(name: String)
        /// No plan and nothing logged. The item is left out rather than shown undone, so a person
        /// training without a plan can still complete the day.
        case nothingPlanned
    }

    struct Nutrition: Equatable {
        let calories: Double
        let proteinGrams: Double
        /// `nil` (or 0) with no diet plan.
        let calorieTarget: Double?
        let proteinTarget: Double?
        let mealsLoggedToday: Int
    }

    struct WeighIn: Equatable {
        let latestKg: Double?
        let isToday: Bool
        /// Change from the last weigh-in at least a week before the latest one.
        let weekChangeKg: Double?
        /// The goal's planned weekly change, signed: negative when losing.
        let goalWeeklyChangeKg: Double?
    }

    struct Steps: Equatable {
        let today: Int
        let goal: Int
        /// Apple Health has given Compound steps at least once. Without it the item is left out;
        /// the starter card offers connecting it instead.
        let hasStepData: Bool
    }

    /// Calories count as on target within this fraction either side, as the weekly review does.
    static let calorieTolerance = WeeklyReview.NutritionAdherence.tolerance

    static let defaultStepGoal = 8_000

    static func build(
        training: Training,
        nutrition: Nutrition,
        weighIn: WeighIn,
        steps: Steps,
        weightUnit: WeightUnitPreference,
        locale: Locale = .autoupdatingCurrent
    ) -> TodayChecklist {
        var items: [Item] = []
        if let item = trainingItem(training) { items.append(item) }
        items.append(nutritionItem(nutrition, locale: locale))
        items.append(weighInItem(weighIn, weightUnit: weightUnit))
        if steps.hasStepData {
            items.append(Item(
                kind: .steps,
                isDone: steps.today >= steps.goal,
                detail: String(localized: "\(steps.today.formatted(.number.locale(locale))) / \(steps.goal.formatted(.number.locale(locale))) steps")
            ))
        }
        return TodayChecklist(items: items)
    }

    private static func trainingItem(_ training: Training) -> Item? {
        switch training {
        case .done(let name): return Item(kind: .training, isDone: true, detail: name)
        case .restDay: return Item(kind: .training, isDone: true, detail: String(localized: "Rest day"))
        case .planned(let name): return Item(kind: .training, isDone: false, detail: name)
        case .nothingPlanned: return nil
        }
    }

    /// With targets: calories inside the band and protein reached. Without a diet plan there is no
    /// target to hit, so logging the day's food is the job.
    private static func nutritionItem(_ nutrition: Nutrition, locale: Locale) -> Item {
        let calories = nutrition.calories.formatted(.number.precision(.fractionLength(0)).locale(locale))
        guard let calorieTarget = nutrition.calorieTarget, calorieTarget > 0 else {
            let logged = nutrition.mealsLoggedToday > 0
            return Item(
                kind: .nutrition,
                isDone: logged,
                detail: logged ? String(localized: "\(calories) kcal logged") : String(localized: "Nothing logged yet")
            )
        }
        let proteinTarget = nutrition.proteinTarget ?? 0
        let caloriesOnTarget = abs(nutrition.calories - calorieTarget) <= calorieTarget * calorieTolerance
        let proteinReached = proteinTarget <= 0 || nutrition.proteinGrams >= proteinTarget
        let calorieText = String(localized: "\(calories) / \(Format.kcal(calorieTarget, locale: locale))")
        let detail = proteinTarget > 0
            ? "\(calorieText) · \(String(localized: "\(Format.grams(nutrition.proteinGrams, locale: locale)) / \(Format.grams(proteinTarget, locale: locale)) protein"))"
            : calorieText
        return Item(kind: .nutrition, isDone: caloriesOnTarget && proteinReached, detail: detail)
    }

    private static func weighInItem(_ weighIn: WeighIn, weightUnit: WeightUnitPreference) -> Item {
        guard let latest = weighIn.latestKg else {
            return Item(kind: .weighIn, isDone: false, detail: String(localized: "No weigh-ins yet"))
        }
        var parts = [Format.weight(kg: latest, unit: weightUnit)]
        if let change = weighIn.weekChangeKg {
            parts.append(String(localized: "\(signedWeight(change, unit: weightUnit)) this week"))
        }
        if let goal = weighIn.goalWeeklyChangeKg, goal != 0 {
            parts.append(String(localized: "goal \(signedWeight(goal, unit: weightUnit))/wk"))
        }
        return Item(kind: .weighIn, isDone: weighIn.isToday, detail: parts.joined(separator: " · "))
    }

    /// "+0.3 kg", "−0.4 kg", "0 kg".
    static func signedWeight(_ kilograms: Double, unit: WeightUnitPreference) -> String {
        let text = Format.weight(kg: abs(kilograms), unit: unit)
        if kilograms > 0.04 { return "+\(text)" }
        if kilograms < -0.04 { return "−\(text)" }
        return text
    }

    // MARK: - Weight trend

    /// The latest weigh-in and its change from the last one at least a week earlier. `nil` change
    /// with no weigh-in that far back.
    static func weightTrend(
        _ measurements: [BodyMeasurementEntry],
        calendar: Calendar = .current
    ) -> (latest: BodyMeasurementEntry?, weekChangeKg: Double?) {
        let weighIns = measurements
            .filter { $0.deletedAt == nil && $0.weightKg != nil }
            .sorted { $0.date < $1.date }
        guard let latest = weighIns.last, let latestKg = latest.weightKg else { return (nil, nil) }
        guard let weekBefore = calendar.date(byAdding: .day, value: -7, to: latest.date),
              let baseline = weighIns.last(where: { $0.date <= weekBefore })?.weightKg else {
            return (latest, nil)
        }
        return (latest, latestKg - baseline)
    }
}

// MARK: - Getting started

/// A new account's first steps, shown on Today until they are all done or dismissed. A first
/// week of empty cards gives no sense of where to begin; this does.
struct TodayStarter: Equatable {

    enum Step: String, CaseIterable, Identifiable {
        case firstWorkout, firstMeal, firstWeighIn, appleHealth, strava
        var id: String { rawValue }

        var title: String {
            switch self {
            case .firstWorkout: return String(localized: "Finish your first workout")
            case .firstMeal: return String(localized: "Log your first meal")
            case .firstWeighIn: return String(localized: "Log your weight")
            case .appleHealth: return String(localized: "Connect Apple Health")
            case .strava: return String(localized: "Connect Strava")
            }
        }
    }

    let done: Set<Step>

    var remaining: [Step] { Step.allCases.filter { !done.contains($0) } }
    var isFinished: Bool { remaining.isEmpty }
}

// MARK: - Friends

enum TodaySocialPulse {

    /// "Sam trained today", "Sam and Alex trained today", "Sam, Alex and 3 others trained today".
    /// `nil` when nobody did, so the line is left out rather than reporting a zero.
    static func text(names: [String]) -> String? {
        let names = names.filter { !$0.isEmpty }
        switch names.count {
        case 0: return nil
        case 1: return String(localized: "\(names[0]) trained today")
        case 2: return String(localized: "\(names[0]) and \(names[1]) trained today")
        default: return String(localized: "\(names[0]), \(names[1]) and \(String(localized: "\(names.count - 2) others")) trained today")
        }
    }

    /// The people followed who finished a workout today, in the order they finished.
    static func namesTrainedToday(
        sessions: [WorkoutSessionModel],
        following: [UserModel],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [String] {
        let people = Dictionary(following.map { ($0.userId, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        return sessions
            .filter { session in
                guard let ended = session.endedAt else { return false }
                return !session.isRestDay && session.deletedAt == nil && calendar.isDate(ended, inSameDayAs: now)
            }
            .sorted { ($0.endedAt ?? .distantPast) < ($1.endedAt ?? .distantPast) }
            .compactMap { session -> String? in
                guard let person = people[session.authorId], seen.insert(session.authorId).inserted else { return nil }
                return person.firstNameCalculated ?? person.displayNameCalculated
            }
    }
}
