//
//  NutritionTargetChartView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 13/10/2025.
//

import SwiftUI

struct NutritionTargetChartView: View {
    @State var presenter: NutritionTargetChartPresenter

    var body: some View {
        Group {
            if let planDays = presenter.planDays {
                if let loggedDays = presenter.loggedDays {
                    grid(planDays: planDays, loggedDays: loggedDays)
                } else {
                    // The week's totals are read in `.task` below. Until they arrive there is
                    // nothing truthful to put in the logged half of each cell.
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                noPlanState
            }
        }
        .task {
            await presenter.loadCurrentWeekLoggedTotals()
        }
    }

    /// Shown when the user has no diet plan. The grid used to draw a week of `DailyMacroTarget.mock`
    /// here, which read as the user's own targets in a screen people take dietary decisions from.
    private var noPlanState: some View {
        ContentUnavailableView {
            Label("No Diet Plan", systemImage: Symbol.meal)
        } description: {
            Text("Create a diet plan and your daily calorie and macro targets appear here.")
        } actions: {
            Button("Create Diet Plan") {
                presenter.onCreatePlanPressed()
            }
            .buttonStyle(.glass)
        }
    }

    private func grid(planDays: [DailyMacroTarget], loggedDays: [DailyMacroTarget]) -> some View {
        Grid(alignment: .center, horizontalSpacing: Spacing.s, verticalSpacing: Spacing.m) {
            // Metric rows
            ForEach(NutritionTargetChartPresenter.Metric.allCases, id: \.self) { metric in
                GridRow {
                    let targetValues = planDays.map { presenter.value(for: metric, day: $0) }
                    let loggedValues = loggedDays.map { presenter.value(for: metric, day: $0) }
                    let maxValue = max(targetValues.max() ?? 1, loggedValues.max() ?? 1)
                    let sumLogged = loggedValues.reduce(0, +)
                    let sumTarget = targetValues.reduce(0, +)

                    // Day cells
                    ForEach(Array(zip(loggedValues, targetValues).enumerated()), id: \.offset) { idx, values in
                        let isToday = idx == presenter.todayIndexMondayStart
                        TargetCellView(value: values.0, targetValue: values.1, maxValue: maxValue, tint: metric.colour)
                            // Today's focus ring, in the accent.
                            .overlay {
                                if isToday {
                                    RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                                        .stroke(.tint, lineWidth: 2)
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(presenter.dayNames[idx]), \(metric.title)")
                            .accessibilityValue(presenter.cellAccessibilityValue(logged: values.0, target: values.1, metric: metric))
                    }

                    // Weekly sum cell
                    OverallTargetCellView(
                        systemImage: metric.systemImage,
                        tint: metric.colour,
                        valueText: presenter.amountText(sumLogged, for: metric),
                        targetText: presenter.amountText(sumTarget, for: metric)
                    )
                    .fixedSize(horizontal: true, vertical: false)
                    .gridColumnAlignment(.leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(metric.title) this week")
                    .accessibilityValue(presenter.cellAccessibilityValue(logged: sumLogged, target: sumTarget, metric: metric))
                }
            }

            // Day labels row
            GridRow {
                ForEach(Array(presenter.dayAbbrevs.enumerated()), id: \.offset) { idx, day in
                    Text(day)
                        .font(.label)
                        .fontWeight(idx == presenter.todayIndexMondayStart ? .bold : .regular)
                        .foregroundStyle(idx == presenter.todayIndexMondayStart ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .padding(.horizontal, Spacing.xxs)
                        .accessibilityHidden(true)
                }
                Text("Week")
                    .font(.label)
                    .accessibilityHidden(true)
                    .foregroundStyle(.secondary)
                    .gridColumnAlignment(.leading)
            }
        }
    }
}

extension CoreBuilder {
    func nutritionTargetChartView(router: AnyRouter) -> some View {
        NutritionTargetChartView(
            presenter: NutritionTargetChartPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    RouterView { router in
        builder.nutritionTargetChartView(router: router)
    }
}
