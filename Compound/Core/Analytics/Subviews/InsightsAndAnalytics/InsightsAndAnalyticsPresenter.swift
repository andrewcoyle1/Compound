import SwiftUI

@Observable
@MainActor
class InsightsAndAnalyticsPresenter {

    private let interactor: InsightsAndAnalyticsInteractor
    private let router: InsightsAndAnalyticsRouter
    private let calendar = Calendar.current

    /// The weigh-ins behind the Weight Trend card. This was a stored property nothing ever wrote
    /// to, so the card read "No Entries" and drew a flat line however many times the user had
    /// weighed themselves.
    private var scaleWeightEntries: [BodyMeasurementEntry] {
        interactor.bodyMeasurements
    }

    private(set) var macrosLast7Days: [DailyMacroTarget] = []
    var workoutLast7Sessions: [WorkoutSessionModel] {
        let completed = workoutSessions
            // A rest day is written ahead of time by the training mesocycle, already ended and dated
            // into the future, so counting it as a workout filled this card with sessions that had
            // not happened and had no sets in them.
            .filter { $0.endedAt != nil && !$0.isRestDay }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
        return Array(completed.prefix(7))
            .sorted { ($0.endedAt ?? .distantPast) < ($1.endedAt ?? .distantPast) }
    }

    var workoutSessions: [WorkoutSessionModel] {
        interactor.workoutSessions
    }
    
    init(interactor: InsightsAndAnalyticsInteractor, router: InsightsAndAnalyticsRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onFirstTask() async {
        loadMacrosData()
    }

    private func loadMacrosData() {
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
                interactor.trackEvent(event: Event.loadMacrosFail(error: error))
                totals.append(DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0))
            }
        }
        macrosLast7Days = totals
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    func onWeightTrendPressed(themeColor: Color?) {
        router.showWeightTrendView(delegate: WeightTrendDelegate(), themeColor: themeColor)
    }

    func onGoalProgressPressed(themeColor: Color?) {
        router.showGoalProgressView(delegate: GoalProgressDelegate(), themeColor: themeColor)
    }

    func onEnergyBalancePressed(themeColor: Color?) {
        router.showEnergyBalanceView(delegate: EnergyBalanceDelegate(), themeColor: themeColor)
    }

    func onWorkoutsPressed(themeColor: Color?) {
        router.showWorkoutView(delegate: WorkoutDelegate(), themeColor: themeColor)
    }

    func onExpenditurePressed(themeColor: Color?) {
        router.showExpenditureDetailView(delegate: ExpenditureDetailDelegate(), themeColor: themeColor)
    }

    // MARK: - Goal progress

    /// The weight entries logged since the goal was set — the same window `GoalProgressView` uses,
    /// so the card and the screen it opens cannot disagree.
    private var goalWeightEntries: [BodyMeasurementEntry] {
        guard let goal = interactor.currentGoal else { return [] }
        return interactor.bodyMeasurements
            .filter { $0.deletedAt == nil && $0.weightKg != nil && $0.date >= goal.createdAt }
            .sorted { $0.date < $1.date }
    }

    var hasActiveGoal: Bool {
        interactor.currentGoal != nil
    }

    /// Clamped to 0...100: the card draws it as a bar, and a goal overshot or moved away from
    /// should read as full or empty rather than send the bar off either end.
    ///
    /// Measured from the trend weight, not the last weigh-in, so a day of water does not move it.
    var goalProgressPercent: Double {
        guard let goal = interactor.currentGoal, !goalWeightEntries.isEmpty,
              let trendWeight = GoalTimeline.latestTrendWeightKg(of: interactor.bodyMeasurements) else { return 0 }
        return min(max(goal.calculateProgress(currentWeight: trendWeight) * 100, 0), 100)
    }

    var goalProgressSubtitle: String {
        guard hasActiveGoal else { return String(localized: "No Goal Set") }
        return goalWeightEntries.isEmpty ? String(localized: "No Entries") : String(localized: "Toward Target")
    }

    var goalProgressLatestValueText: String {
        guard hasActiveGoal, !goalWeightEntries.isEmpty else { return Format.placeholder }
        return goalProgressPercent.formatted(.number.precision(.fractionLength(0)))
    }

    var goalProgressUnitText: String {
        "%"
    }

    /// Weight is stored in kilograms; only the display converts.
    var weightUnit: WeightUnitPreference {
        interactor.currentUser?.submittedWeightUnitPreference ?? .kilograms
    }

    /// The last seven points of the trend over every weigh-in, so the card's line is the same one
    /// the Weight Trend screen draws rather than a trend restarted from a week of readings.
    var weightTrendSparklineData: [(date: Date, value: Double)] {
        let pairs = scaleWeightEntries
            .filter { $0.deletedAt == nil }
            .sorted { $0.date < $1.date }
            .compactMap { entry -> (date: Date, value: Double)? in
                guard let weightKg = entry.weightKg else { return nil }
                return (date: entry.date, value: weightKg)
            }
        // Smoothed in kilograms and converted afterwards — the conversion is linear, so this is the
        // same curve, computed once.
        return WeightTrendCalculator.trend(data: pairs).suffix(7)
            .map { (date: $0.date, value: UnitConversion.convertWeight($0.value, to: weightUnit)) }
    }

    var weightTrendSubtitle: String {
        weightTrendLastEntries.isEmpty ? String(localized: "No Entries") : String(localized: "Last 7 Days")
    }

    var weightTrendLatestValueText: String {
        let trend = weightTrendSparklineData
        guard let last = trend.last else { return Format.placeholder }
        return last.value.formatted(.number.precision(.fractionLength(1)))
    }

    var weightTrendUnitText: String {
        weightUnit.abbreviation
    }

    /// The adaptive estimate day by day (`EnergyBalanceSummary`), not the static formula.
    var energyBalanceExpenditure: TimeSeries {
        let expenditure = EnergyBalanceSummary.expenditureLookup(
            history: interactor.expenditureHistory,
            formulaKcal: interactor.estimateTDEE(user: interactor.currentUser),
            calendar: calendar
        )
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) else {
            return TimeSeries(name: "Expenditure", data: [])
        }
        var data: [TimeSeriesDatapoint] = []
        for offset in -1..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
            data.append(TimeSeriesDatapoint(id: "exp-\(offset)", date: date, value: expenditure(date)))
        }
        return TimeSeries(name: "Expenditure", data: data)
    }

    var energyBalanceIntake: TimeSeries {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) else {
            return TimeSeries(name: "Intake", data: [])
        }
        var data: [TimeSeriesDatapoint] = []
        for (offset, totals) in macrosLast7Days.enumerated() {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
            data.append(TimeSeriesDatapoint(id: "intake-\(offset)", date: date, value: totals.calories))
        }
        return TimeSeries(name: "Intake", data: data)
    }

    /// Says how many days the average was taken over, since unlogged days are left out of it.
    var energyBalanceSubtitle: String {
        guard macrosLast7Days.count == 7 else { return String(localized: "Last 7 Days") }
        return EnergyBalanceSummary.loggedDaysSubtitle(
            days: EnergyBalanceSummary.loggedAverage(macrosLast7Days.map(\.calories))?.days
        )
    }

    /// The week's average over its logged days against the adaptive estimate. An unlogged day is
    /// a day we know nothing about, so it is left out rather than counted as eating nothing.
    var energyBalanceLatestValueText: String {
        guard macrosLast7Days.count == 7,
              let average = EnergyBalanceSummary.loggedAverage(macrosLast7Days.map(\.calories)) else {
            return Format.placeholder
        }
        let expenditure = EnergyBalanceSummary.currentExpenditure(
            history: interactor.expenditureHistory,
            formulaKcal: interactor.estimateTDEE(user: interactor.currentUser)
        )
        return EnergyBalanceSummary.balanceText(expenditureKcal: expenditure, intakeKcal: average.meanKcal)
    }

    var workoutSparklineData: [(date: Date, value: Double)] {
        workoutLast7Sessions.map { session in
            let date = session.endedAt ?? session.dateCreated
            let setCount = session.exercises.flatMap { $0.sets }.filter { !$0.isWarmup }.count
            return (date: date, value: Double(setCount))
        }
    }

    var workoutSubtitle: String {
        workoutLast7Sessions.isEmpty ? String(localized: "No Workouts") : String(localized: "Last 7 Workouts")
    }

    var workoutLatestValueText: String {
        let total = workoutLast7Sessions.reduce(0) { sum, session in
            sum + session.exercises.flatMap { $0.sets }.filter { !$0.isWarmup }.count
        }
        return total > 0 ? total.formatted() : Format.placeholder
    }

    var workoutUnitText: String {
        String(localized: "sets")
    }

    /// Was a flat line off `estimateTDEE` repeated seven times. See `AnalyticsPresenter`'s copy of
    /// this property for why.
    var expenditureSparklineData: [(date: Date, value: Double)] {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) else {
            return []
        }
        let expenditure = EnergyBalanceSummary.expenditureLookup(
            history: interactor.expenditureHistory,
            formulaKcal: interactor.estimateTDEE(user: interactor.currentUser),
            calendar: calendar
        )
        return (0..<7).compactMap { offset -> (date: Date, value: Double)? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            return (date: date, value: expenditure(date))
        }
    }

    var expenditureSubtitle: String {
        String(localized: "Last 7 Days")
    }

    /// Today's adaptive estimate, or the formula figure before there is one.
    var expenditureLatestValueText: String {
        let tdee = EnergyBalanceSummary.currentExpenditure(
            history: interactor.expenditureHistory,
            formulaKcal: interactor.estimateTDEE(user: interactor.currentUser)
        )
        return tdee > 0 ? tdee.formatted(.number.precision(.fractionLength(0))) : Format.placeholder
    }

    var expenditureUnitText: String {
        "kcal"
    }

    private var weightTrendLastEntries: [BodyMeasurementEntry] {
        let filtered = scaleWeightEntries.filter { $0.deletedAt == nil && $0.weightKg != nil }
        let sorted = filtered.sorted { $0.date < $1.date }
        return Array(sorted.suffix(7))
    }
}

extension InsightsAndAnalyticsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case loadMacrosFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:    return "InsightsAndAnalyticsView_Appear"
            case .onDisappear: return "InsightsAndAnalyticsView_Disappear"
            case .loadMacrosFail: return "InsightsAndAnalyticsView_LoadMacros_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .loadMacrosFail(let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .loadMacrosFail:
                return .warning
            default:
                return .analytic
            }
        }
    }
}
