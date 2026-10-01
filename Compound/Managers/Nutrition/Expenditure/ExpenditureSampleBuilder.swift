//
//  ExpenditureSampleBuilder.swift
//  Compound
//

import Foundation

/// Folds the three logs the engine reads into one `DailySample` per calendar day.
///
/// Kept separate from `CoreInteractor` so the gathering rules — which days count as logged, how
/// two weigh-ins in a day are reconciled, which steps record wins — are testable on their own.
enum ExpenditureSampleBuilder {

    /// One sample per day from the first day with any data up to and including yesterday.
    ///
    /// Today is never a sample: it is incomplete by definition, and a half-eaten day read as a
    /// finished one would drag the estimate down every morning and back up every evening.
    static func samples(
        mealLogs: [MealLogModel],
        measurements: [BodyMeasurementEntry],
        steps: [StepsModel],
        annotations: [NutritionDayAnnotation] = [],
        loggingBreak: LoggingBreak? = nil,
        today: Date,
        calendar: Calendar = .current
    ) -> [DailySample] {
        let startOfToday = calendar.startOfDay(for: today)
        let intake = intakeByDay(mealLogs, calendar: calendar)
        let weights = weightByDay(measurements, calendar: calendar)
        let stepCounts = stepsByDay(steps, calendar: calendar)
        let annotationsByDay = annotationByDay(annotations, calendar: calendar)

        let allDays = Set(intake.keys).union(weights.keys).union(stepCounts.keys)
            .filter { $0 < startOfToday }
        guard let first = allDays.min(),
              let last = calendar.date(byAdding: .day, value: -1, to: startOfToday),
              first <= last else { return [] }

        var result: [DailySample] = []
        var day = first
        while day <= last {
            let annotation = annotationsByDay[day]
            // A fasting day with nothing logged really is zero. Left as nil it would be one more
            // unlogged day, and the mean would quietly assume the user ate like every other day —
            // the opposite of what they said happened.
            let isFastingWithNoLogs = (annotation?.isFastingDay ?? false) && intake[day] == nil
            let isInBreak = loggingBreak?.contains(day) ?? false
            result.append(
                DailySample(
                    day: day,
                    intakeKcal: isFastingWithNoLogs ? 0 : intake[day],
                    weightKg: weights[day],
                    steps: stepCounts[day],
                    isExcluded: (annotation?.isPartiallyLogged ?? false) || isInBreak
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// Annotations keyed by the day they describe; an unparseable `dayKey` is dropped rather than
    /// guessed at.
    private static func annotationByDay(
        _ annotations: [NutritionDayAnnotation],
        calendar: Calendar
    ) -> [Date: NutritionDayAnnotation] {
        var result: [Date: NutritionDayAnnotation] = [:]
        for annotation in annotations {
            guard let date = Date(dayKey: annotation.dayKey) else { continue }
            result[calendar.startOfDay(for: date)] = annotation
        }
        return result
    }

    /// A day with meal logs is logged even when they add up to zero calories; a day with none is
    /// not logged at all. That is the whole difference `minLoggedFraction` is measuring.
    private static func intakeByDay(_ mealLogs: [MealLogModel], calendar: Calendar) -> [Date: Double] {
        var result: [Date: Double] = [:]
        for meal in mealLogs {
            let day = calendar.startOfDay(for: Date(dayKey: meal.dayKey) ?? meal.date)
            result[day, default: 0] += meal.totalCalories
        }
        return result
    }

    /// Several weigh-ins in one day are averaged; the trend cares about the day, not the scale trip.
    private static func weightByDay(
        _ measurements: [BodyMeasurementEntry],
        calendar: Calendar
    ) -> [Date: Double] {
        var totals: [Date: (sum: Double, count: Int)] = [:]
        for entry in measurements where entry.deletedAt == nil {
            guard let weight = entry.weightKg, weight.isFinite, weight > 0 else { continue }
            let day = calendar.startOfDay(for: entry.date)
            totals[day, default: (0, 0)].sum += weight
            totals[day, default: (0, 0)].count += 1
        }
        return totals.mapValues { $0.sum / Double($0.count) }
    }

    /// HealthKit and a manual entry can both land on one day; the larger is the fuller count.
    private static func stepsByDay(_ steps: [StepsModel], calendar: Calendar) -> [Date: Int] {
        var result: [Date: Int] = [:]
        for record in steps where record.deletedAt == nil {
            let day = calendar.startOfDay(for: record.date)
            result[day] = max(result[day] ?? 0, record.number)
        }
        return result
    }
}
