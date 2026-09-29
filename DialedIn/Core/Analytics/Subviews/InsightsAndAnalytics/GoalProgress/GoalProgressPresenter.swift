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
                VStack(spacing: 16) {
                    Image(systemName: "target")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Active Weight Goal")
                        .font(.headline)
                    Text("Set a weight goal in Profile to track your progress toward your target.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            )
        }

        let progress = currentWeightKg.map { goal.calculateProgress(currentWeight: $0) } ?? 0
        let progressPercent = progress * 100

        return AnyView(
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.objective.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(Int(progressPercent))%")
                            .font(.title)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }

                MacroProgressChart(
                    current: progressPercent,
                    target: 100,
                    maxValue: 100,
                    color: .green
                )
                .frame(height: 24)

                HStack {
                    weightLabel("Start", goal.startingWeightKg)
                    Spacer()
                    if let current = currentWeightKg {
                        weightLabel("Current", current)
                        Spacer()
                    }
                    weightLabel("Target", goal.targetWeightKg)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
        )
    }

    private func weightLabel(_ title: String, _ kilos: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text("\(kilos.formatted(.number.precision(.fractionLength(1)))) kg")
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
            chartColor: .green
        )
    }

    func onAddPressed() {
        onAddWeightPressed()
    }

}
