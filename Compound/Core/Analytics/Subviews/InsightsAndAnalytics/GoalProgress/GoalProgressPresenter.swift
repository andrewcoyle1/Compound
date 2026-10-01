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

    var currentWeightKg: Double? {
        weightEntriesSinceGoal.last?.weightKg
    }

    func onSetGoalPressed() {
        router.showWeightGoalFlow()
    }
}

extension GoalProgressPresenter: @MainActor MetricDetailPresenter {
    
    func onAppear() async { }
    
    typealias Entry = GoalProgressEntry

    var entries: [GoalProgressEntry] {
        guard let goal = activeGoal else { return [] }
        return weightEntriesSinceGoal.compactMap { entry in
            guard let weightKg = entry.weightKg else { return nil }
            return GoalProgressEntry(
                id: entry.id,
                date: entry.date,
                weightKg: weightKg,
                progressPercent: goal.calculateProgress(currentWeight: weightKg) * 100,
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
                        weightLabel("Current", current)
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
