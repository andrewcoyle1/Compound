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
            // A rest day is written ahead of time by the training program, already ended and dated
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
    var goalProgressPercent: Double {
        guard let goal = interactor.currentGoal,
              let latestWeight = goalWeightEntries.last?.weightKg else { return 0 }
        return min(max(goal.calculateProgress(currentWeight: latestWeight) * 100, 0), 100)
    }

    var goalProgressSubtitle: String {
        guard hasActiveGoal else { return "No Goal Set" }
        return goalWeightEntries.isEmpty ? String(localized: "No Entries") : String(localized: "Toward Target")
    }

    var goalProgressLatestValueText: String {
        guard hasActiveGoal, !goalWeightEntries.isEmpty else { return "--" }
        return "\(Int(goalProgressPercent.rounded()))"
    }

    var goalProgressUnitText: String {
        "%"
    }

    /// Weight is stored in kilograms; only the display converts.
    var weightUnit: WeightUnitPreference {
        interactor.currentUser?.submittedWeightUnitPreference ?? .kilograms
    }

    var weightTrendSparklineData: [(date: Date, value: Double)] {
        let pairs = weightTrendLastEntries.compactMap { entry -> (date: Date, value: Double)? in
            guard let weightKg = entry.weightKg else { return nil }
            return (date: entry.date, value: weightKg)
        }
        // Smoothed in kilograms and converted afterwards — the conversion is linear, so this is the
        // same curve, computed once.
        return WeightTrendCalculator.exponentialMovingAverage(data: pairs)
            .map { (date: $0.date, value: UnitConversion.convertWeight($0.value, to: weightUnit)) }
    }

    var weightTrendSubtitle: String {
        weightTrendLastEntries.isEmpty ? String(localized: "No Entries") : String(localized: "Last 7 Days")
    }

    var weightTrendLatestValueText: String {
        let trend = weightTrendSparklineData
        guard let last = trend.last else { return "--" }
        return last.value.formatted(.number.precision(.fractionLength(1)))
    }

    var weightTrendUnitText: String {
        weightUnit.abbreviation
    }

    var energyBalanceExpenditure: TimeSeries {
        let tdee = interactor.estimateTDEE(user: interactor.currentUser)
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) else {
            return TimeSeries(name: "Expenditure", data: [])
        }
        var data: [TimeSeriesDatapoint] = []
        for offset in -1..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
            data.append(TimeSeriesDatapoint(id: "exp-\(offset)", date: date, value: tdee))
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

    var energyBalanceSubtitle: String {
        String(localized: "Last 7 Days")
    }

    var energyBalanceLatestValueText: String {
        guard macrosLast7Days.count == 7 else { return "--" }
        let tdee = interactor.estimateTDEE(user: interactor.currentUser)
        let avgIntake = macrosLast7Days.map(\.calories).reduce(0, +) / 7
        let deficit = tdee - avgIntake
        let value = Int(deficit.rounded())
        if value > 0 {
            return String(localized: "\(String(describing: value)) deficit")
        } else if value < 0 {
            return String(localized: "\(String(describing: -value)) surplus")
        }
        return String(localized: "Balanced")
    }

    var energyBalanceUnitText: String {
        "kcal"
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
        return total > 0 ? "\(total)" : "--"
    }

    var workoutUnitText: String {
        "sets"
    }

    var expenditureSparklineData: [(date: Date, value: Double)] {
        let tdee = interactor.estimateTDEE(user: interactor.currentUser)
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) else {
            return []
        }
        return (0..<7).compactMap { offset -> (date: Date, value: Double)? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            return (date: date, value: tdee)
        }
    }

    var expenditureSubtitle: String {
        String(localized: "Last 7 Days")
    }

    var expenditureLatestValueText: String {
        let tdee = interactor.estimateTDEE(user: interactor.currentUser)
        return tdee > 0 ? "\(Int(tdee.rounded()))" : "--"
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

        var eventName: String {
            switch self {
            case .onAppear:    return "InsightsAndAnalyticsView_Appear"
            case .onDisappear: return "InsightsAndAnalyticsView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }
}
