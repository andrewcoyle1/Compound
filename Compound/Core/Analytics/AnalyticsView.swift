//
//  AnalyticsView.swift
//  Compound
//
//  Created by Andrew Coyle on 25/09/2025.
//

import SwiftUI

struct AnalyticsDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct AnalyticsView<HeaderCarousel: View>: View {

    @Environment(\.scenePhase) private var scenePhase

    @State var presenter: AnalyticsPresenter
    let delegate: AnalyticsDelegate
    let profileButtonTransition: String = "profile_button_transition"
    @ViewBuilder var headerCarousel: () -> HeaderCarousel

    @Namespace private var namespace
    
    var body: some View {
        List {
            Group {
                headerSection
                // Which of these appear is the Customise Analytics screen's business. The header and
                // the More list below are not hideable: one is the summary, the other is how you
                // reach everything that has been hidden.
                if presenter.isVisible(.insightsAndAnalytics) { insightsAndAnalyticsSection }
                if presenter.isVisible(.habits) { habitsSection }
                if presenter.isVisible(.nutrition) { nutritionSection }
                if presenter.isVisible(.bodyMetrics) { bodyMetricsSection }
                if presenter.isVisible(.muscleGroups) { muscleGroupsSection }
                if presenter.isVisible(.exercises) { exercisesSection }
                generalSection
            }
            .listSectionMargins(.horizontal, 0)
            .listRowSeparator(.hidden)
            moreSection
        }
        // As QuickCharts' `ChartScreen` does for its chart: the header's colour carries on up behind
        // the navigation bar, even when the list is pulled down.
        .topFill(Color.surface)
        // The card grids add columns with width, so this tab takes more of a wide window.
        .preferredReadableContentWidth(ContentWidth.dashboard)
        .navigationTitle("Progress")
        .minimizingLargeTitleBar()
        .scrollIndicators(.hidden)
        .toolbar {
            toolbarContent
        }
        // A tab root stays alive across tab switches, so it loads once and then refreshes on the
        // events that can change its data (foregrounding, a remote sync) rather than on every
        // appearance. The pushed and sheeted Analytics screens that show "Today" use `.task`.
        .onFirstTask {
            await presenter.onFirstTask()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await presenter.onFirstTask() }
            }
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .onNotificationReceived(name: Constants.remoteDataSyncDidComplete) { _ in
            Task { await presenter.onFirstTask() }
        }
    }
    
    /// The carousel at the top: the week against its targets, then today's nutrition, energy
    /// balance, this week's training and recent records.
    private var headerSection: some View {
        Section {
            headerCarousel()
                .padding(.bottom, Spacing.m)
                .frame(maxWidth: .infinity)
                .topFillEdge()
                // Edge to edge and up to the navigation bar, on the colour `topFill` carries above it.
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.surface)
        }
        .listSectionMargins(.all, 0)
        .listSectionSeparator(.hidden)
    }

    private var moreSection: some View {
        Section {
            ForEach(presenter.hiddenSections) { section in
                ListRowButton(title: section.title, systemImage: section.systemImage) {
                    presenter.onHiddenSectionPressed(section)
                }
            }

            ListRowButton(title: String(localized: "Weekly Review"), systemImage: "chart.bar.doc.horizontal") {
                presenter.onWeeklyReviewPressed()
            }

            // "house" here was copied from the Dashboard tab and said nothing about what the row
            // does.
            ListRowButton(title: String(localized: "Customize Analytics"), systemImage: "slider.horizontal.3") {
                presenter.onCustomiseAnalyticsPressed()
            }
        } header: {
            Text("More")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    presenter.onLogWeightPressed()
                } label: {
                    Label("Log Weight", systemImage: Symbol.scaleWeight)
                }
                Menu {
                    ForEach(presenter.measurementMenuSections, id: \.header) { section in
                        Section(section.header) {
                            ForEach(section.kinds) { kind in
                                Button(LocalizedStringKey(kind.displayName)) {
                                    presenter.onLogMeasurementPressed(kind: kind)
                                }
                            }
                        }
                    }
                } label: {
                    Label("Log Measurement", systemImage: "ruler")
                }
            } label: {
                Image(systemName: Symbol.add)
            }
            .accessibilityLabel("Log body metrics")
        }

        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            ProfileButton(
                action: {
                    presenter.onProfilePressed(transitionId: profileButtonTransition, namespace: namespace)
                },
                imageUrl: presenter.userImageUrl
            )
            .matchedTransitionSource(id: profileButtonTransition, in: namespace)
        }
    }
}

// MARK: - Analytics Sections (extracted for type_body_length)
//
// Every section is the same three pieces: a `SectionHeaderView`, an `AnalyticsCardGrid`, and
// cards built from the shared card components in `AnalyticsSection.swift`. Sections whose contents
// are data-driven fall back to an `AnalyticsEmptyCard` so a visible header is never followed by a
// blank grid.
private extension AnalyticsView {

    var insightsAndAnalyticsSection: some View {
        let workoutColor = Color.Metric.workouts
        let expenditureColor = Color.Metric.expenditure
        let weightTrendColor = Color.Metric.scaleWeight
        let goalProgressColor = Color.Metric.goalProgress
        return Section {
            AnalyticsCardGrid {
                AnalyticsCard(
                    title: String(localized: "Workouts"),
                    subtitle: presenter.workoutSubtitle,
                    value: presenter.workoutLatestValueText,
                    unit: presenter.workoutUnitText,
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

                SparklineAnalyticsCard(
                    title: String(localized: "Expenditure"),
                    subtitle: presenter.expenditureSubtitle,
                    value: presenter.expenditureLatestValueText,
                    unit: presenter.expenditureUnitText,
                    themeColor: expenditureColor,
                    data: presenter.expenditureSparklineData,
                    action: { presenter.onExpenditurePressed(themeColor: expenditureColor) }
                )

                SparklineAnalyticsCard(
                    title: String(localized: "Weight Trend"),
                    subtitle: presenter.weightTrendSubtitle,
                    value: presenter.weightTrendLatestValueText,
                    unit: presenter.weightTrendUnitText,
                    themeColor: weightTrendColor,
                    data: presenter.weightTrendSparklineData,
                    action: { presenter.onWeightTrendPressed(themeColor: weightTrendColor) }
                )

                // Was hardcoded to "14%" over "Last 7 Days" — a placeholder that showed the same
                // number to every user, including users with no goal at all.
                AnalyticsCard(
                    title: String(localized: "Goal Progress"),
                    subtitle: presenter.goalProgressSubtitle,
                    value: presenter.goalProgressLatestValueText,
                    unit: presenter.goalProgressUnitText,
                    themeColor: goalProgressColor,
                    chartConfiguration: .compact
                ) {
                    MacroProgressChart(
                        current: presenter.goalProgressPercent,
                        target: 100,
                        maxValue: 100,
                        color: goalProgressColor,
                        unit: "%"
                    )
                }
                .analyticsCardButton {
                    presenter.onGoalProgressPressed(themeColor: goalProgressColor)
                }

                AnalyticsCard(
                    title: String(localized: "Energy Balance"),
                    subtitle: presenter.energyBalanceSubtitle,
                    value: presenter.energyBalanceLatestValueText,
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
        } header: {
            SectionHeaderView(
                title: String(localized: "Insights & Analytics"),
                onActionPressed: { presenter.onSeeAllInsightsPressed() }
            )
        }
    }

    var habitsSection: some View {
        Section {
            AnalyticsCardGrid {
                ConsistencyAnalyticsCard(
                    title: String(localized: "Weigh In"),
                    value: presenter.weighInCountThisWeek.formatted(),
                    themeColor: Color.Metric.habits,
                    data: presenter.weighInContributionData,
                    action: { presenter.onWeighInConsistencyPressed(themeColor: Color.Metric.habits) }
                )
                ConsistencyAnalyticsCard(
                    title: String(localized: "Workouts"),
                    value: presenter.workoutCountThisWeek.formatted(),
                    themeColor: Color.Metric.habits,
                    data: presenter.workoutContributionData,
                    action: { presenter.onWorkoutConsistencyPressed(themeColor: Color.Metric.habits) }
                )
            }
        } header: {
            SectionHeaderView(
                title: String(localized: "Habits"),
                onActionPressed: { presenter.onSeeAllHabitsPressed() }
            )
        }
    }

    var nutritionSection: some View {
        let macrosColor = Color.Metric.nutrition
        let proteinColor = Color.protein
        return Section {
            AnalyticsCardGrid {
                AnalyticsCard(
                    title: String(localized: "Macros"),
                    subtitle: presenter.macrosLast7Days.isEmpty ? String(localized: "No Data") : String(localized: "Last 7 Days"),
                    value: presenter.macrosLast7Days.isEmpty ? Format.placeholder : presenter.macrosAverageCalories.formatted(.number.precision(.fractionLength(0))),
                    unit: "kcal",
                    themeColor: macrosColor,
                    chartConfiguration: .compact,
                    chart: {
                        let chartData = presenter.macrosLast7Days.isEmpty
                            ? Array(repeating: DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0), count: 7)
                            : presenter.macrosLast7Days
                        return MacroStackedBarChart(data: chartData)
                    }
                )
                .analyticsCardButton {
                    presenter.onMacrosPressed(themeColor: macrosColor)
                }
                AnalyticsCard(
                    title: String(localized: "Protein"),
                    subtitle: presenter.macrosLast7Days.isEmpty ? String(localized: "No Data") : String(localized: "Today"),
                    value: presenter.macrosLast7Days.isEmpty ? Format.placeholder : presenter.proteinCurrent.formatted(.number.precision(.fractionLength(1))),
                    unit: "g",
                    themeColor: proteinColor,
                    chartConfiguration: .compact,
                    chart: {
                        MacroProgressChart(
                            current: presenter.proteinCurrent,
                            target: presenter.proteinTarget,
                            maxValue: presenter.proteinMax,
                            color: proteinColor,
                            unit: "g"
                        )
                    }
                )
                .analyticsCardButton {
                    presenter.onProteinPressed(themeColor: proteinColor)
                }
            }
        } header: {
            SectionHeaderView(
                title: String(localized: "Nutrition"),
                onActionPressed: { presenter.onSeeAllNutritionAnalyticsPressed() }
            )
        }
    }

    var bodyMetricsSection: some View {
        let scaleWeightColor = Color.Metric.scaleWeight
        let bodyFatColor = Color.Metric.bodyFat
        return Section {
            AnalyticsCardGrid {
                SparklineAnalyticsCard(
                    title: String(localized: "Scale Weight"),
                    subtitle: presenter.scaleWeightSubtitle,
                    value: presenter.scaleWeightLatestValueText,
                    unit: presenter.scaleWeightUnitText,
                    themeColor: scaleWeightColor,
                    data: presenter.scaleWeightSparklineData,
                    action: { presenter.onScaleWeightPressed(themeColor: scaleWeightColor) }
                )
                SparklineAnalyticsCard(
                    title: String(localized: "Visual Body Fat"),
                    subtitle: presenter.bodyFatSubtitle,
                    value: presenter.bodyFatLatestValueText,
                    unit: presenter.bodyFatUnitText,
                    themeColor: bodyFatColor,
                    data: presenter.bodyFatSparklineData,
                    action: { presenter.onVisualBodyFatPressed(themeColor: bodyFatColor) }
                )
            }
        } header: {
            SectionHeaderView(
                title: String(localized: "Body Metrics"),
                onActionPressed: { presenter.onSeeAllBodyMetricsPressed() }
            )
        }
    }

    var muscleGroupsSection: some View {
        let muscleGroupColor = Color.Metric.muscleGroups
        return Section {
            AnalyticsCardGrid {
                if presenter.muscleGroupCards.isEmpty {
                    AnalyticsEmptyCard(message: String(localized: "Log a workout to see your weekly sets by muscle group."))
                } else {
                    ForEach(presenter.muscleGroupCards, id: \.muscle) { item in
                        AnalyticsCard(
                            title: item.muscle.name,
                            subtitle: String(localized: "Last 7 Days"),
                            value: item.totalSets.formatted(.number.precision(.fractionLength(0...1))),
                            unit: String(localized: "sets"),
                            themeColor: muscleGroupColor,
                            chartConfiguration: .compact
                        ) {
                            SetsBarChart(data: item.last7DaysData, color: muscleGroupColor)
                        }
                        .analyticsCardButton {
                            presenter.onMuscleGroupPressed(muscle: item.muscle, themeColor: muscleGroupColor)
                        }
                    }
                }
            }
        } header: {
            SectionHeaderView(
                title: String(localized: "Muscle Groups"),
                onActionPressed: { presenter.onSeeAllMuscleGroupsPressed() }
            )
            .methodInfo(.weeklyHardSets)
        }
    }

    var exercisesSection: some View {
        let exerciseColor = Color.Metric.exercises
        return Section {
            AnalyticsCardGrid {
                if presenter.exerciseCards.isEmpty {
                    AnalyticsEmptyCard(message: String(localized: "Log a workout to track your estimated one-rep max."))
                } else {
                    ForEach(presenter.exerciseCards) { item in
                        SparklineAnalyticsCard(
                            title: item.name,
                            subtitle: String(localized: "Last 7 Workouts"),
                            value: item.latest1RM > 0 ? item.latest1RM.formatted(.number.precision(.fractionLength(1))) : Format.placeholder,
                            unit: item.unitText,
                            themeColor: exerciseColor,
                            data: item.sparklineData,
                            action: {
                                presenter.onExercisePressed(
                                    templateId: item.templateId,
                                    name: item.name,
                                    themeColor: exerciseColor
                                )
                            }
                        )
                    }
                }
            }
        } header: {
            SectionHeaderView(
                title: String(localized: "Exercises"),
                onActionPressed: { presenter.onSeeAllExercisesPressed() }
            )
            .methodInfo(.estimatedOneRepMax)
        }
    }

    var generalSection: some View {
        let stepsColor = Color.Metric.steps
        return Section {
            AnalyticsCardGrid {
                SparklineAnalyticsCard(
                    title: String(localized: "Steps"),
                    subtitle: presenter.stepsSubtitle,
                    value: presenter.stepsLatestValueText,
                    unit: presenter.stepsUnitText,
                    themeColor: stepsColor,
                    data: presenter.stepsSparklineData,
                    action: { presenter.onStepsPressed(themeColor: stepsColor) }
                )
            }
        } header: {
            SectionHeaderView(title: String(localized: "General"))
        }
    }
}

extension CoreBuilder {
    
    func analyticsView(delegate: AnalyticsDelegate, router: AnyRouter) -> some View {
        AnalyticsView(
            presenter: AnalyticsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate,
            headerCarousel: {
                self.progressCarouselView(router: router)
            }
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = AnalyticsDelegate()
    RouterView { router in
        builder.analyticsView(delegate: delegate, router: router)
    }
    
}

#Preview("w/ Notifications Test") {
    let container = DevPreview.shared.container()
    container.register(ABTestManager.self, service: ABTestManager(service: MockABTestService(notificationsTest: true), logger: LogManager()))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = AnalyticsDelegate()
    return RouterView { router in
        builder.analyticsView(delegate: delegate, router: router)
    }
    
}
