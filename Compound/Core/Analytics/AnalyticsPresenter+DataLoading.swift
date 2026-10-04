//
//  AnalyticsPresenter+DataLoading.swift
//  Compound
//

import SwiftUI

@MainActor
extension AnalyticsPresenter {
    
    func loadWorkoutData() {
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let startOfToday = calendar.startOfDay(for: now)
        let startOf30DaysAgo = calendar.startOfDay(for: thirtyDaysAgo)
        let completedSessions = workoutSessions.filter { session in
            guard let endedAt = session.endedAt else { return false }
            let sessionDate = calendar.startOfDay(for: endedAt)
            return sessionDate >= startOf30DaysAgo && sessionDate <= startOfToday
        }
        workoutCountThisWeek = workoutCountThisWeek(from: completedSessions)
        workoutContributionData = workoutContributionData(from: completedSessions)
        let completed = workoutSessions
            .filter { $0.endedAt != nil }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
        workoutLast7Sessions = Array(completed.prefix(7))
            .sorted { ($0.endedAt ?? .distantPast) < ($1.endedAt ?? .distantPast) }
    }
    
    func workoutCountThisWeek(from completedSessions: [WorkoutSessionModel]) -> Int {
        let now = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        let weekStart = calendar.startOfDay(for: weekInterval.start)
        let weekEnd = calendar.startOfDay(for: weekInterval.end)
        return completedSessions.filter { session in
            guard let endedAt = session.endedAt else { return false }
            let sessionDate = calendar.startOfDay(for: endedAt)
            return sessionDate >= weekStart && sessionDate < weekEnd
        }.count
    }
    
    func workoutContributionData(from completedSessions: [WorkoutSessionModel]) -> [Double] {
        var contributionData = Array(repeating: 0.0, count: 30)
        let workoutDates = Set(completedSessions.compactMap { session -> Date? in
            guard let endedAt = session.endedAt else { return nil }
            return calendar.startOfDay(for: endedAt)
        })
        let now = Date()
        let endDate = calendar.startOfDay(for: now)
        let totalDays = 3 * 10
        let chartStartDate = calendar.date(byAdding: .day, value: -(totalDays - 1), to: endDate) ?? endDate
        for column in 0..<10 {
            for row in 0..<3 {
                let dayOffset = column * 3 + row
                if let cellDate = calendar.date(byAdding: .day, value: dayOffset, to: chartStartDate) {
                    let normalizedCellDate = calendar.startOfDay(for: cellDate)
                    if workoutDates.contains(normalizedCellDate) {
                        let dataIndex = column * 3 + row
                        if dataIndex < 30 { contributionData[dataIndex] = 1.0 }
                    }
                }
            }
        }
        return contributionData
    }
    
    func loadMuscleGroupsData() {
        let completed = workoutSessions.filter { $0.endedAt != nil }
        
        let templateIds = Set(completed.flatMap { $0.exercises.map(\.templateId) })
        let templates: [String: ExerciseModel]
        if templateIds.isEmpty {
            templates = [:]
        } else {
            templates = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })
        }
        
        let aggregated = MuscleGroupSetsAggregator.aggregate(
            sessions: completed,
            templates: templates,
            calendar: calendar
        )
        
        // The cards say "Last 7 Days" and chart those days, so they count and rank by them. The
        // aggregate's `total` is every workout ever logged, which both used to show and sort by.
        func weekSets(_ muscle: Muscles) -> Double {
            aggregated[muscle]?.last7Days.reduce(0, +) ?? 0
        }
        let musclesWithData = Muscles.allCases
            .filter { weekSets($0) > 0 }
            .sorted { weekSets($0) > weekSets($1) }

        let shown = musclesWithData.isEmpty ? [Muscles.upperBack, Muscles.rearDelts] : Array(musclesWithData.prefix(2))
        muscleGroupCards = shown.map { muscle in
            MuscleGroupCardItem(
                muscle: muscle,
                last7DaysData: aggregated[muscle]?.last7Days ?? Array(repeating: 0.0, count: 7),
                totalSets: weekSets(muscle)
            )
        }
    }
    
    func loadExerciseCardsData() async {
        let completed = workoutSessions.filter { $0.endedAt != nil }
        let aggregated = ExerciseOneRMAggregator.aggregate(sessions: completed)
        
        var seenIds = Set<String>()
        let allExercises = (userExercises + systemExercises)
            .filter { seenIds.insert($0.id).inserted }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        
        let allCards = allExercises.map { (exercise: ExerciseModel) -> ExerciseCardItem in
            let data = aggregated[exercise.id]
            let unit = interactor.getPreference(templateId: exercise.id).weightUnit
            let sparkline: [(date: Date, value: Double)] = (data?.last7Workouts ?? []).map {
                (date: $0.date, value: UnitConversion.convertWeight($0.value, to: unit))
            }
            return ExerciseCardItem(
                templateId: exercise.id,
                name: exercise.name,
                sparklineData: sparkline,
                latest1RM: UnitConversion.convertWeight(data?.latest1RM ?? 0, to: unit),
                unitText: unit.abbreviation
            )
        }
        exerciseCards = Array(allCards.sorted { $0.latest1RM > $1.latest1RM }.prefix(2))
    }
    
    /// Computed rather than loaded, so a weigh-in logged from this tab's + menu is counted as soon
    /// as it syncs. It was filled once on the first task, which a sheet's dismissal never re-runs.
    var weighInSummary: (countThisWeek: Int, contribution: [Double]) {
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let startOfToday = calendar.startOfDay(for: now)
        let startOf30DaysAgo = calendar.startOfDay(for: thirtyDaysAgo)

        let weightEntries = interactor.bodyMeasurements.filter { entry in
            guard entry.deletedAt == nil,
                  entry.weightKg != nil else { return false }
            let entryDate = calendar.startOfDay(for: entry.date)
            return entryDate >= startOf30DaysAgo && entryDate <= startOfToday
        }

        let countThisWeek: Int
        if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) {
            let weekStart = calendar.startOfDay(for: weekInterval.start)
            let weekEnd = calendar.startOfDay(for: weekInterval.end)
            countThisWeek = weightEntries.filter { entry in
                let entryDate = calendar.startOfDay(for: entry.date)
                return entryDate >= weekStart && entryDate < weekEnd
            }.count
        } else {
            countThisWeek = 0
        }

        var contributionData = Array(repeating: 0.0, count: 30)
        let weighInDates = Set(weightEntries.map { calendar.startOfDay(for: $0.date) })
        let endDate = calendar.startOfDay(for: now)
        let totalDays = 3 * 10
        let chartStartDate = calendar.date(byAdding: .day, value: -(totalDays - 1), to: endDate) ?? endDate

        for column in 0..<10 {
            for row in 0..<3 {
                let dayOffset = column * 3 + row
                if let cellDate = calendar.date(byAdding: .day, value: dayOffset, to: chartStartDate) {
                    let normalizedCellDate = calendar.startOfDay(for: cellDate)
                    if weighInDates.contains(normalizedCellDate) {
                        let dataIndex = column * 3 + row
                        if dataIndex < 30 { contributionData[dataIndex] = 1.0 }
                    }
                }
            }
        }
        return (countThisWeek, contributionData)
    }
    
    func loadMacrosData() {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return }
        
        var totals: [DailyMacroTarget] = []
        totals.reserveCapacity(7)
        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
            let key = date.dayKey
            do {
                let dayTotals = try interactor.getDailyTotals(dayKey: key)
                totals.append(dayTotals)
            } catch {
                totals.append(DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0))
            }
        }
        macrosLast7Days = totals
    }
    
    func loadDailyTarget() async {
        guard let userId = interactor.userId else {
            dailyTarget = nil
            return
        }
        let now = Date()
        do {
            dailyTarget = try await interactor.getDailyTarget(for: now, userId: userId)
        } catch {
            dailyTarget = nil
        }
    }
    
    func loadStepsData() async {
        await interactor.syncStepsFromHealthKit(fromScratch: false)
    }

    /// Read live, so steps imported from Apple Health appear while the tab is open.
    var stepsLast7: [StepsModel] {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday),
              let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return []
        }
        let userId = interactor.userId
        // Bounded by the end of today, not its start: a reading is dated when it was taken, so
        // `<= startOfToday` kept only a reading timed exactly at midnight and dropped today's.
        let last7 = interactor.stepsHistory
            .filter { $0.deletedAt == nil && $0.date >= startDate && $0.date < endOfToday && (userId == nil || $0.authorId == userId) }
            .sorted { $0.date < $1.date }
        return Array(Self.consolidateStepsByDay(Array(last7)).suffix(7))
    }
    
    static func consolidateStepsByDay(_ entries: [StepsModel]) -> [StepsModel] {
        let byDay = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
        return byDay.compactMap { (_, dayEntries) in
            dayEntries.max { $0.number < $1.number }
        }.sorted { $0.date < $1.date }
    }
}
