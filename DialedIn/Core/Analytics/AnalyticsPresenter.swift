//
//  AnalyticsPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/10/2025.
//

import SwiftUI

@Observable
@MainActor
class AnalyticsPresenter {
    let interactor: AnalyticsInteractor
    let router: AnalyticsRouter

    var showNotifications: Bool = false

    // Workout data (set from AnalyticsPresenter+DataLoading)
    var workoutContributionData: [Double] = []
    var workoutCountThisWeek: Int = 0
    var workoutLast7Sessions: [WorkoutSessionModel] = []

    // Weigh-in data (set from AnalyticsPresenter+DataLoading)
    var weighInContributionData: [Double] = []
    var weighInCountThisWeek: Int = 0

    // Macros (last 7 days) (set from AnalyticsPresenter+DataLoading)
    var macrosLast7Days: [DailyMacroTarget] = []
    var dailyTarget: DailyMacroTarget?

    // Steps (set from AnalyticsPresenter+DataLoading)
    var stepsLast7: [StepsModel] = []

    // Muscle groups (set from AnalyticsPresenter+DataLoading)
    var muscleGroupCards: [MuscleGroupCardItem] = []

    // Exercises (set from AnalyticsPresenter+DataLoading)
    var exerciseCards: [ExerciseCardItem] = []

    let calendar = Calendar.current

    var isInNotificationsABTest: Bool {
        interactor.activeTests.notificationsTest
    }

    var userImageUrl: String? {
        interactor.userImageUrl
    }

    var workoutSessions: [WorkoutSessionModel] {
        interactor.workoutSessions
    }
    
    var systemExercises: [ExerciseModel] {
        interactor.systemExercises
    }
    
    var userExercises: [ExerciseModel] {
        interactor.userExercises
    }
    
    var allExercises: [ExerciseModel] {
        interactor.allExercises
    }
    
    // MARK: - Nutrition (today's totals from macrosLast7Days.last)
    private var dailyTotals: DailyMacroTarget? { macrosLast7Days.last }

    var macrosAverageCalories: Double {
        guard !macrosLast7Days.isEmpty else { return 0 }
        return macrosLast7Days.map(\.calories).reduce(0, +) / Double(macrosLast7Days.count)
    }

    var proteinCurrent: Double { dailyTotals?.proteinGrams ?? 0 }
    var proteinTarget: Double? { dailyTarget?.proteinGrams }
    var proteinMax: Double {
        let target = dailyTarget?.proteinGrams ?? 150
        return max(proteinCurrent, target * 1.2)
    }

    init(
        interactor: AnalyticsInteractor,
        router: AnalyticsRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: AnalyticsDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: AnalyticsDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onFirstTask() async {
        loadWorkoutData()
        loadWeighInData()
        loadMacrosData()
        await loadDailyTarget()
        loadMuscleGroupsData()
        await loadExerciseCardsData()
        await loadStepsData()
    }
    
    // `handleDeepLink(url:)` and `handlePushNotificationRecieved(notification:)` were here. Both
    // parsed their input into a loop whose body was a comment — "Do something with value" — fired
    // analytics, and navigated nowhere. Both now live on `TabBarPresenter`, which is the only place
    // in the app that can actually change what is on screen; see `DeepLink`.

    func onDevSettingsPressed() {
        #if MOCK || DEV
        interactor.trackEvent(event: Event.onDevSettings)
        router.showDevSettingsView()
        #else
        interactor.trackEvent(event: Event.onDevSettingsFail)
        #endif
    }

    func onSubscribePressed() {
        router.showPaywall()
    }

    func onProfilePressed(transitionId: String, namespace: Namespace.ID) {
        router.showProfileViewZoom(transitionId: transitionId, namespace: namespace)
    }

    func onScaleWeightPressed(themeColor: Color?) {
        router.showScaleWeightView(delegate: ScaleWeightDelegate(), themeColor: themeColor)
    }

    func onWeighInConsistencyPressed(themeColor: Color?) {
        router.showWeighInConsistencyView(delegate: WeighInConsistencyDelegate(), themeColor: themeColor)
    }

    func onVisualBodyFatPressed(themeColor: Color?) {
        router.showVisualBodyFatView(delegate: VisualBodyFatDelegate(), themeColor: themeColor)
    }
    
    func onSeeAllInsightsPressed() {
        router.showInsightsAndAnalyticsView(delegate: InsightsAndAnalyticsDelegate())
    }
    
    func onSeeAllHabitsPressed() {
        router.showHabitsView(delegate: HabitsDelegate())
    }
    
    func onSeeAllNutritionAnalyticsPressed() {
        router.showNutritionAnalyticsView(delegate: NutritionAnalyticsDelegate())
    }

    func onMacrosPressed(themeColor: Color?) {
        router.showNutritionMetricDetailView(metric: .macros, delegate: NutritionMetricDetailDelegate(), themeColor: themeColor)
    }

    func onProteinPressed(themeColor: Color?) {
        router.showNutritionMetricDetailView(metric: .protein, delegate: NutritionMetricDetailDelegate(), themeColor: themeColor)
    }
    
    func onSeeAllBodyMetricsPressed() {
        router.showBodyMetricsView(delegate: BodyMetricsDelegate())
    }
    
    func onSeeAllMuscleGroupsPressed() {
        router.showMuscleGroupsView(delegate: MuscleGroupsDelegate())
    }

    func onMuscleGroupPressed(muscle: Muscles, themeColor: Color?) {
        router.showMuscleGroupDetailView(muscle: muscle, delegate: MuscleGroupDetailDelegate(), themeColor: themeColor)
    }

    func onExercisePressed(templateId: String, name: String, themeColor: Color?) {
        router.showExerciseDetailView(templateId: templateId, name: name, delegate: ExerciseDetailDelegate(), themeColor: themeColor)
    }
    
    func onSeeAllExercisesPressed() {
        router.showExerciseAnalyticsView(delegate: ExerciseAnalyticsDelegate())
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

    func onWorkoutConsistencyPressed(themeColor: Color?) {
        router.showWorkoutConsistencyView(delegate: WorkoutConsistencyDelegate(), themeColor: themeColor)
    }

    func onExpenditurePressed(themeColor: Color?) {
        router.showExpenditureDetailView(delegate: ExpenditureDetailDelegate(), themeColor: themeColor)
    }

    func onStepsPressed(themeColor: Color?) {
        router.showStepsView(delegate: StepsDelegate(), themeColor: themeColor)
    }

    var stepsSparklineData: [(date: Date, value: Double)] {
        stepsLast7.map { (date: $0.date, value: Double($0.number)) }
    }

    var stepsSubtitle: String {
        stepsLast7.isEmpty ? String(localized: "No Data") : String(localized: "Last 7 Days")
    }

    var stepsLatestValueText: String {
        guard let latest = stepsLast7.last else { return "--" }
        return "\(latest.number)"
    }

    var stepsUnitText: String {
        "steps"
    }

    /// The user's weight unit, used for every body-weight number on this tab. Weight is stored in
    /// kilograms; only the display converts.
    var weightUnit: WeightUnitPreference {
        interactor.currentUser?.submittedWeightUnitPreference ?? .kilograms
    }

    var scaleWeightSparklineData: [(date: Date, value: Double)] {
        scaleWeightLastEntries.compactMap { entry in
            guard let weightKg = entry.weightKg else { return nil }
            return (date: entry.date, value: UnitConversion.convertWeight(weightKg, to: weightUnit))
        }
    }

    var scaleWeightSubtitle: String {
        scaleWeightLastEntries.isEmpty ? String(localized: "No Entries") : String(localized: "Last 7 Entries")
    }

    var scaleWeightLatestValueText: String {
        guard let latest = scaleWeightLastEntries.last,
              let weightKg = latest.weightKg else { return "--" }
        return UnitConversion.formatWeight(weightKg, unit: weightUnit)
    }

    var scaleWeightUnitText: String {
        weightUnit.abbreviation
    }

    /// The last seven weight entries, computed once per change of `bodyMeasurements` rather than
    /// once per read. Six properties read this, and the view reads several of them in one pass.
    private var scaleWeightLastEntries: [BodyMeasurementEntry] {
        bodyMetricsCache.weightEntries
    }

    /// Smoothed in kilograms and converted afterwards — the conversion is linear, so this is the
    /// same curve. Cached: `weightTrendLatestValueText` reads it as well as the chart, so the
    /// moving average used to run twice per body evaluation.
    var weightTrendSparklineData: [(date: Date, value: Double)] {
        bodyMetricsCache.weightTrend
    }

    var weightTrendSubtitle: String {
        scaleWeightLastEntries.isEmpty ? String(localized: "No Entries") : String(localized: "Last 7 Days")
    }

    var weightTrendLatestValueText: String {
        guard let last = weightTrendSparklineData.last else { return "--" }
        // Already converted by `weightTrendSparklineData`.
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

    var bodyFatSparklineData: [(date: Date, value: Double)] {
        bodyFatLastEntries.compactMap { entry in
            guard let bodyFatPercentage = entry.bodyFatPercentage else { return nil }
            return (date: entry.date, value: bodyFatPercentage)
        }
    }

    var bodyFatSubtitle: String {
        bodyFatLastEntries.isEmpty ? String(localized: "No Entries") : String(localized: "Last 7 Entries")
    }

    var bodyFatLatestValueText: String {
        guard let latest = bodyFatLastEntries.last,
              let bodyFatPercentage = latest.bodyFatPercentage else {
            return "--"
        }
        return bodyFatPercentage.formatted(.number.precision(.fractionLength(1)))
    }

    var bodyFatUnitText: String {
        "%"
    }

    private var bodyFatLastEntries: [BodyMeasurementEntry] {
        bodyMetricsCache.bodyFatEntries
    }

    var workoutSparklineData: [(date: Date, value: Double)] {
        workoutLast7Sessions.map { session in
            let date = session.endedAt ?? session.dateCreated
            let setCount = session.exercises.reduce(0) { $0 + $1.workingSetCount }
            return (date: date, value: Double(setCount))
        }
    }

    var workoutSubtitle: String {
        workoutLast7Sessions.isEmpty ? String(localized: "No Workouts") : String(localized: "Last 7 Workouts")
    }

    var workoutLatestValueText: String {
        let total = workoutLast7Sessions.reduce(0) { sum, session in
            sum + session.exercises.reduce(0) { $0 + $1.workingSetCount }
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
    
    // MARK: - Body metrics cache

    /// Derived from `interactor.bodyMeasurements` in one pass, and recomputed only when that
    /// changes. These were computed properties, so every read re-filtered and re-sorted the whole
    /// measurement history — and one body evaluation of `AnalyticsView` reads them a dozen times
    /// between the Scale Weight, Weight Trend and Visual Body Fat cards.
    private struct BodyMetricsCache {
        var signature: Int = 0
        var weightEntries: [BodyMeasurementEntry] = []
        var bodyFatEntries: [BodyMeasurementEntry] = []
        var weightTrend: [(date: Date, value: Double)] = []
    }

    private var cachedBodyMetrics = BodyMetricsCache()

    private var bodyMetricsCache: BodyMetricsCache {
        let measurements = interactor.bodyMeasurements
        // Entries are immutable structs replaced on save — clearing a weight keeps the count and the
        // id — so the signature covers the fields actually read below. That is one pass with no
        // allocations, against the filter, two sorts and a moving average it guards.
        var hasher = Hasher()
        hasher.combine(measurements.count)
        hasher.combine(weightUnit)
        for entry in measurements {
            hasher.combine(entry.id)
            hasher.combine(entry.date)
            hasher.combine(entry.weightKg)
            hasher.combine(entry.bodyFatPercentage)
            hasher.combine(entry.deletedAt)
        }
        let signature = hasher.finalize()

        if cachedBodyMetrics.signature == signature {
            return cachedBodyMetrics
        }

        let live = measurements.filter { $0.deletedAt == nil }
        let weightEntries = Array(
            live.filter { $0.weightKg != nil }.sorted { $0.date < $1.date }.suffix(7)
        )
        let bodyFatEntries = Array(
            live.filter { $0.bodyFatPercentage != nil }.sorted { $0.date < $1.date }.suffix(7)
        )
        let pairs = weightEntries.compactMap { entry -> (date: Date, value: Double)? in
            guard let weightKg = entry.weightKg else { return nil }
            return (date: entry.date, value: weightKg)
        }
        let trend = WeightTrendCalculator.exponentialMovingAverage(data: pairs)
            .map { (date: $0.date, value: UnitConversion.convertWeight($0.value, to: weightUnit)) }

        let rebuilt = BodyMetricsCache(
            signature: signature,
            weightEntries: weightEntries,
            bodyFatEntries: bodyFatEntries,
            weightTrend: trend
        )
        cachedBodyMetrics = rebuilt
        return rebuilt
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

    /// Honours the Customise Analytics screen. Reads the settings document directly rather than
    /// snapshotting it, so hiding a section on that screen updates this one behind it.
    func isVisible(_ section: AnalyticsSection) -> Bool {
        interactor.analyticsSettings.isVisible(section)
    }

    /// The sections currently switched off, in the order they would otherwise appear. The
    /// Customise Analytics screen promises these "stay reachable from the More list at the bottom of
    /// the tab" — before this the More list held one row, Customise Analytics itself, so hiding a
    /// section made it unreachable.
    var hiddenSections: [AnalyticsSection] {
        AnalyticsSection.allCases.filter { !isVisible($0) }
    }

    /// Opens a hidden section's own screen — the same destination its "See All" would have used.
    func onHiddenSectionPressed(_ section: AnalyticsSection) {
        switch section {
        case .insightsAndAnalytics: onSeeAllInsightsPressed()
        case .habits:               onSeeAllHabitsPressed()
        case .nutrition:            onSeeAllNutritionAnalyticsPressed()
        case .bodyMetrics:          onSeeAllBodyMetricsPressed()
        case .muscleGroups:         onSeeAllMuscleGroupsPressed()
        case .exercises:            onSeeAllExercisesPressed()
        }
    }

    func onCustomiseAnalyticsPressed() {
        router.showCustomiseAnalyticsView(delegate: CustomiseAnalyticsDelegate())
    }

    func onWeeklyReviewPressed() {
        router.showWeeklyReviewView()
    }

    enum Event: LoggableEvent {
        case onAppear(delegate: AnalyticsDelegate)
        case onDisappear(delegate: AnalyticsDelegate)
        case onDevSettings
        case onDevSettingsFail

        var eventName: String {
            switch self {
            case .onAppear:                 return "AnalyticsView_Appear"
            case .onDisappear:              return "AnalyticsView_Disappear"
            case .onDevSettings:            return "AnalyticsView_DevSettings"
            case .onDevSettingsFail:        return "AnalyticsView_DevSettings_Fail"

            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .onDevSettingsFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
