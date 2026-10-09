//
//  GoalProgressPresenter.swift
//  Compound
//

import SwiftUI

@Observable
@MainActor
class GoalProgressPresenter {

    private let interactor: GoalProgressInteractor
    private let router: GoalProgressRouter

    var activeGoal: WeightGoal? {
        interactor.currentGoal
    }
    
    /// The user's own unit. Goals and weigh-ins are stored in kilograms.
    var weightUnit: WeightUnitPreference {
        interactor.currentUser?.submittedWeightUnitPreference ?? .kilograms
    }

    init(interactor: GoalProgressInteractor, router: GoalProgressRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    func onAddWeightPressed() {
        router.showLogWeightView()
    }

    /// Weigh-ins since the goal was set. Read live, so a goal set from this screen's empty state,
    /// or a weigh-in imported while it is open, shows straight away.
    private var weightEntriesSinceGoal: [BodyMeasurementEntry] {
        guard let goal = activeGoal else { return [] }
        return interactor.bodyMeasurements
            .filter { $0.deletedAt == nil && $0.weightKg != nil && $0.date >= goal.createdAt }
            .sorted { $0.date < $1.date }
    }

    /// Every weigh-in's trend weight, smoothed over the whole history so the first ones after the
    /// goal was set are not a fresh start (`GoalTimeline.trend`).
    private var trendSinceGoal: [(entry: BodyMeasurementEntry, trendKg: Double)] {
        guard let goal = activeGoal else { return [] }
        return GoalTimeline.trend(of: interactor.bodyMeasurements).filter { $0.entry.date >= goal.createdAt }
    }

    /// The trend weight now, not the last weigh-in: progress should not jump with a day of water.
    var currentWeightKg: Double? {
        guard !weightEntriesSinceGoal.isEmpty else { return nil }
        return GoalTimeline.latestTrendWeightKg(of: interactor.bodyMeasurements)
    }

    func onSetGoalPressed() {
        router.showWeightGoalFlow(editing: nil)
    }

    /// Edit the running goal or start a new one.
    func onChangeGoalPressed() {
        guard let goal = activeGoal, goal.status == .active else {
            router.showWeightGoalFlow(editing: nil)
            return
        }
        WeightGoalChoices.show(
            on: router,
            onEdit: { [weak self] in self?.router.showWeightGoalFlow(editing: goal) },
            onStartNew: { [weak self] in self?.router.showWeightGoalFlow(editing: nil) }
        )
    }
}

extension GoalProgressPresenter: @MainActor MetricDetailPresenter {
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onAppear() async { }
    
    typealias Entry = GoalProgressEntry

    /// Each weigh-in as logged, with the progress its trend weight stood at.
    var entries: [GoalProgressEntry] {
        guard let goal = activeGoal else { return [] }
        return trendSinceGoal.compactMap { point in
            guard let weightKg = point.entry.weightKg else { return nil }
            return GoalProgressEntry(
                id: point.entry.id,
                date: point.entry.date,
                weightKg: weightKg,
                progressPercent: goal.calculateProgress(currentWeight: point.trendKg) * 100,
                weightUnit: weightUnit
            )
        }
    }

    var timeSeries: [TimeSeries] {
        guard activeGoal != nil else { return [] }
        return [TimeSeries(name: "Progress", data: entries.map { TimeSeriesDatapoint(id: $0.id, date: $0.date, value: $0.progressPercent) })]
    }

    var customChartView: AnyView? {
        guard let goal = activeGoal else {
            return AnyView(
                ContentUnavailableView {
                    Label("No Active Weight Goal", systemImage: Symbol.goal)
                } description: {
                    Text("Set a weight goal to track your progress toward your target.")
                } actions: {
                    Button("Set Goal") { self.onSetGoalPressed() }
                        .buttonStyle(.borderedProminent)
                }
            )
        }

        let progress = currentWeightKg.map { goal.calculateProgress(currentWeight: $0) } ?? 0
        let progressPercent = progress * 100

        return AnyView(
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(goal.objective.description)
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                    Text(Format.percent(progress))
                        .font(.metricLarge)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                MacroProgressChart(
                    current: progressPercent,
                    target: 100,
                    maxValue: 100,
                    color: Color.Metric.goalProgress,
                    unit: "%"
                )
                .frame(height: ControlSize.icon)

                HStack {
                    weightLabel("Start", goal.startingWeightKg)
                    Spacer()
                    if let current = currentWeightKg {
                        weightLabel("Trend", current)
                        Spacer()
                    }
                    weightLabel("Target", goal.targetWeightKg)
                }
                .font(.label)
                .foregroundStyle(.secondary)
            }
            .padding()
        )
    }

    /// A stored kilogram weight in the user's unit, as the entries show it.
    func weightText(_ kilos: Double) -> String {
        Format.weight(kg: kilos, unit: weightUnit)
    }

    private func weightLabel(_ title: LocalizedStringKey, _ kilos: Double) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
            Text(weightText(kilos))
                .fontWeight(.medium)
        }
    }

    var configuration: MetricConfiguration {
        MetricConfiguration(
            title: String(localized: "Goal Progress"),
            analyticsName: "GoalProgressView",
            yAxisSuffix: "%",
            seriesNames: ["Progress"],
            showsAddButton: activeGoal != nil,
            sectionHeader: "Weight History",
            emptyStateMessage: activeGoal == nil
                ? "Set a weight goal to track your progress."
                : "Log your weight to track progress toward your target.",
            chartColor: Color.Metric.goalProgress
        )
    }

    func onAddPressed() {
        onAddWeightPressed()
    }

}

extension GoalProgressPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear: return "GoalProgressView_Appear"
            case .onDisappear: return "GoalProgressView_Disappear"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }
}
