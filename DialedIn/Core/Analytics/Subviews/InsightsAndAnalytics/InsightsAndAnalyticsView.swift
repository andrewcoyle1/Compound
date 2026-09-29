import SwiftUI

struct InsightsAndAnalyticsDelegate {
    
}

struct InsightsAndAnalyticsView: View {
    
    @State var presenter: InsightsAndAnalyticsPresenter
    let delegate: InsightsAndAnalyticsDelegate
    
    var body: some View {
        List {
            activitySection
            energySection
            bodySection
            goalsSection
        }
        .navigationTitle("Insights & Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .onFirstTask {
            await presenter.onFirstTask()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close) {
                    presenter.onDismissPressed()
                }
            }
        }
    }

    private var activitySection: some View {
        let workoutColor = Color.orange
        return analyticsSection(title: String(localized: "Activity")) {
            AnalyticsCard(
                title: String(localized: "Workouts"),
                subtitle: presenter.workoutSubtitle,
                subsubtitle: presenter.workoutLatestValueText,
                subsubsubtitle: presenter.workoutUnitText,
                themeColor: workoutColor,
                chartConfiguration: .compact
            ) {
                SetsBarChart(
                    data: presenter.workoutSparklineData.map(\.value),
                    slotCount: 7,
                    color: workoutColor
                )
            }
            .analyticsCardButton {
                presenter.onWorkoutsPressed(themeColor: workoutColor)
            }
        }
    }

    private var energySection: some View {
        let expenditureColor = Color.pink
        return analyticsSection(title: String(localized: "Energy")) {
            SparklineAnalyticsCard(
                title: String(localized: "Expenditure"),
                subtitle: presenter.expenditureSubtitle,
                value: presenter.expenditureLatestValueText,
                unit: presenter.expenditureUnitText,
                themeColor: expenditureColor,
                data: presenter.expenditureSparklineData,
                action: { presenter.onExpenditurePressed(themeColor: expenditureColor) }
            )
            AnalyticsCard(
                title: String(localized: "Energy Balance"),
                subtitle: presenter.energyBalanceSubtitle,
                subsubtitle: presenter.energyBalanceLatestValueText,
                subsubsubtitle: presenter.energyBalanceUnitText,
                themeColor: nil,
                chartConfiguration: .compact
            ) {
                EnergyBalanceChart(
                    expenditure: presenter.energyBalanceExpenditure,
                    energyIntake: presenter.energyBalanceIntake
                )
            }
            .analyticsCardButton {
                presenter.onEnergyBalancePressed(themeColor: nil)
            }
        }
    }

    private var bodySection: some View {
        let weightTrendColor = Color.purple
        return analyticsSection(title: String(localized: "Body")) {
            SparklineAnalyticsCard(
                title: String(localized: "Weight Trend"),
                subtitle: presenter.weightTrendSubtitle,
                value: presenter.weightTrendLatestValueText,
                unit: presenter.weightTrendUnitText,
                themeColor: weightTrendColor,
                data: presenter.weightTrendSparklineData,
                action: { presenter.onWeightTrendPressed(themeColor: weightTrendColor) }
            )
        }
    }

    private var goalsSection: some View {
        let goalProgressColor = Color.green
        // Was hardcoded to "14%" over "Last 7 Days", the same placeholder the Analytics tab carried.
        return analyticsSection(title: String(localized: "Goals")) {
            AnalyticsCard(
                title: String(localized: "Goal Progress"),
                subtitle: presenter.goalProgressSubtitle,
                subsubtitle: presenter.goalProgressLatestValueText,
                subsubsubtitle: presenter.goalProgressUnitText,
                themeColor: goalProgressColor,
                chartConfiguration: .compact,
                chart: {
                    MacroProgressChart(
                        current: presenter.goalProgressPercent,
                        target: 100,
                        maxValue: 100,
                        color: goalProgressColor
                    )
                }
            )
            .analyticsCardButton {
                presenter.onGoalProgressPressed(themeColor: goalProgressColor)
            }
        }
    }

    /// The section shape this screen repeats four times, and the same one the Analytics tab uses.
    private func analyticsSection<Content: View>(
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Section {
            AnalyticsCardGrid(content: content)
        } header: {
            SectionHeaderView(title: title)
        }
        .listSectionMargins(.horizontal, 0)
        .listRowSeparator(.hidden)
    }
}

extension CoreBuilder {
    
    func insightsAndAnalyticsView(router: AnyRouter, delegate: InsightsAndAnalyticsDelegate) -> some View {
        InsightsAndAnalyticsView(
            presenter: InsightsAndAnalyticsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showInsightsAndAnalyticsView(delegate: InsightsAndAnalyticsDelegate) {
        router.showScreen(.sheet) { router in
            builder.insightsAndAnalyticsView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = InsightsAndAnalyticsDelegate()
    
    return RouterView { router in
        builder.insightsAndAnalyticsView(router: router, delegate: delegate)
    }
    
}
