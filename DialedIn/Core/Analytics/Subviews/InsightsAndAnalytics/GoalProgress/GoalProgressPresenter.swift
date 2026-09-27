//
//  GoalProgressPresenter.swift
//  DialedIn
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
    
    private(set) var cachedEntries: [GoalProgressEntry] = []
    private(set) var cachedTimeSeries: [TimeSeries] = []
    private(set) var currentWeightKg: Double?

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

    private func rebuildCaches() {
        guard let goal = activeGoal else {
            cachedEntries = []
            cachedTimeSeries = []
            currentWeightKg = nil
            return
        }

        let weightEntries = interactor.bodyMeasurements
            .filter { $0.deletedAt == nil && $0.weightKg != nil && $0.date >= goal.createdAt }
            .sorted { $0.date < $1.date }

        let entries: [GoalProgressEntry] = weightEntries.compactMap { entry in
            guard let weightKg = entry.weightKg else { return nil }
            let progress = goal.calculateProgress(currentWeight: weightKg)
            return GoalProgressEntry(
                id: entry.id,
                date: entry.date,
                weightKg: weightKg,
                progressPercent: progress * 100
            )
        }

        cachedEntries = entries
        currentWeightKg = weightEntries.last?.weightKg

        let progressData = entries.map {
            TimeSeriesDatapoint(id: $0.id, date: $0.date, value: $0.progressPercent)
        }
        cachedTimeSeries = [
            TimeSeries(name: "Progress", data: progressData)
        ]
    }
}

extension GoalProgressPresenter: @MainActor MetricDetailPresenter {
    
    /// `MetricDetailView` calls this, and it was empty. `rebuildCaches()` had one caller, a
    /// `loadData()` with no call sites of its own, so nothing ever populated `cachedEntries` and the
    /// screen came up empty however much weight history existed. `loadData()` is gone with the gap.
    func onAppear() async {
        rebuildCaches()
    }
    
    typealias Entry = GoalProgressEntry

    var entries: [GoalProgressEntry] {
        cachedEntries
    }

    var timeSeries: [TimeSeries] {
        cachedTimeSeries
    }

    var customChartView: AnyView? {
        guard let goal = activeGoal else {
            return AnyView(
                ContentUnavailableView(
                    "No Active Weight Goal",
                    systemImage: Symbol.goal,
                    description: Text("Set a weight goal in Profile to track your progress toward your target.")
                )
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

    private func weightLabel(_ title: String, _ kilos: Double) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
            // Kilograms, as the entries and chart on this screen are.
            Text(Format.weight(kg: kilos, unit: WeightUnitPreference.kilograms))
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
                ? "Set a weight goal in Profile to track your progress."
                : "Log your weight to track progress toward your target.",
            chartColor: Color.Metric.goalProgress
        )
    }

    func onAddPressed() {
        onAddWeightPressed()
    }

}
