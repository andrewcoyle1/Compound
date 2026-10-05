//
//  NutritionTargetChartView.swift
//  Compound
//
//  Created by Andrew Coyle on 13/10/2025.
//

import SwiftUI

struct NutritionTargetChartView: View {
    @State var presenter: NutritionTargetChartPresenter

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            // Nothing on screen named this chart or its custom marks before: a bar's fill is what
            // was eaten, the tick is the target, and the caret is for going well over it.
            SectionHeaderView(title: String(localized: "This Week Against Your Targets"))
                .carouselTitleStyle()
            Group {
                if let planDays = presenter.planDays {
                    if let loggedDays = presenter.loggedDays {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            grid(planDays: planDays, loggedDays: loggedDays)
                            // The key sits at the foot of the page, level with the other pages' toggles.
                            Spacer(minLength: 0)
                            key
                        }
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
        }
        .task {
            await presenter.loadCurrentWeekLoggedTotals()
        }
    }

    private var key: some View {
        Text("Bar shows what you ate, the tick is your target, and a caret means you went over.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }

    /// Shown when the user has no diet plan. The grid used to draw a week of `DailyMacroTarget.mock`
    /// here, which read as the user's own targets in a screen people take dietary decisions from.
    private var noPlanState: some View {
        ContentUnavailableView {
            Label("No Diet Plan", systemImage: Symbol.meal)
        } description: {
            Text("Create a diet plan and your daily calorie and macro targets appear here.")
        } actions: {
            Button {
                presenter.onCreatePlanPressed()
            } label: {
                Text("Create Diet Plan")
                    .foregroundStyle(.onAccent)
            }
            .buttonStyle(.borderedProminent)
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
                    let summary = presenter.summary(logged: loggedValues, targets: targetValues)

                    // Day cells
                    ForEach(Array(zip(loggedValues, targetValues).enumerated()), id: \.offset) { idx, values in
                        TargetCellView(value: values.0, targetValue: values.1, maxValue: maxValue, tint: metric.colour)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(presenter.dayNames[idx]), \(metric.title)")
                            .accessibilityValue(presenter.cellAccessibilityValue(logged: values.0, target: values.1, metric: metric))
                            .dayColumn(idx, presenter: presenter)
                    }

                    // The selected day's figures, or the week's when no day is selected.
                    OverallTargetCellView(
                        systemImage: metric.systemImage,
                        tint: metric.colour,
                        valueText: presenter.amountText(summary.logged, for: metric),
                        targetText: presenter.amountText(summary.target, for: metric)
                    )
                    .contentTransition(.numericText())
                    .fixedSize(horizontal: true, vertical: false)
                    .gridColumnAlignment(.leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(summaryLabel(metric))
                    .accessibilityValue(presenter.cellAccessibilityValue(logged: summary.logged, target: summary.target, metric: metric))
                }
            }

            dayLabelsRow
        }
        .overlayPreferenceValue(SelectedDayColumnKey.self, selectedColumnOutline)
        .reducedMotionAnimation(.quick, value: presenter.selectedDayIndex)
    }

    private var dayLabelsRow: some View {
        GridRow {
            ForEach(Array(presenter.dayAbbrevs.enumerated()), id: \.offset) { idx, day in
                Text(day)
                    .font(.label)
                    .fontWeight(idx == presenter.selectedDayIndex ? .bold : .regular)
                    .foregroundStyle(idx == presenter.todayIndexInWeek ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .padding(.horizontal, Spacing.xxs)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                    .dayColumn(idx, presenter: presenter)
            }
            // Names what the last column holds while it holds the week.
            Text("Week")
                .font(.label)
                .accessibilityHidden(true)
                .foregroundStyle(.secondary)
                .opacity(presenter.selectedDayIndex == nil ? 1 : 0)
                .gridColumnAlignment(.leading)
        }
    }

    /// One outline round the whole selected column, as the cells' own strokes could not span the
    /// gaps between rows.
    private func selectedColumnOutline(_ anchors: [Anchor<CGRect>]) -> some View {
        GeometryReader { geo in
            if let column = anchors.map({ geo[$0] }).reduce(nil, { $0?.union($1) ?? $1 }) {
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .stroke(.tint, lineWidth: 2)
                    .frame(width: column.width + Spacing.s, height: column.height + Spacing.s)
                    .position(x: column.midX, y: column.midY)
            }
        }
        .allowsHitTesting(false)
    }

    private func summaryLabel(_ metric: NutritionTargetChartPresenter.Metric) -> String {
        guard let index = presenter.selectedDayIndex else { return String(localized: "\(metric.title) this week") }
        return "\(metric.title), \(presenter.dayNames[index])"
    }
}

/// The bounds of the selected column's cells, collected for the outline drawn round them.
private struct SelectedDayColumnKey: PreferenceKey {
    static let defaultValue: [Anchor<CGRect>] = []

    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value += nextValue()
    }
}

private extension View {
    /// Makes a cell of day `index`'s column select that day, and marks it for the outline.
    func dayColumn(_ index: Int, presenter: NutritionTargetChartPresenter) -> some View {
        let isSelected = presenter.selectedDayIndex == index
        return contentShape(.rect)
            .onTapGesture { presenter.onDayPressed(index) }
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityHint(isSelected ? Text("Shows the week") : Text("Shows this day"))
            .anchorPreference(key: SelectedDayColumnKey.self, value: .bounds) { isSelected ? [$0] : [] }
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
