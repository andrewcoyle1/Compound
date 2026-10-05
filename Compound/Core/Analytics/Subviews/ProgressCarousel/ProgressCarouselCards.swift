//
//  ProgressCarouselCards.swift
//  Compound
//
//  The four pages `ProgressCarouselView` adds after the weekly target grid. Each is a title, the
//  figures, and a toggle at the foot choosing what they are measured against.
//

import SwiftUI

private func whole(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0)))
}

// MARK: - Daily nutrition

struct DailyNutritionCard: View {
    @Bindable var presenter: ProgressCarouselPresenter

    private var showsRemaining: Bool { presenter.dailyShowsRemaining }

    var body: some View {
        CarouselPage(title: String(localized: "Daily Nutrition")) {
            HStack {
                Stat(
                    value: showsRemaining ? whole(presenter.caloriesConsumed) : presenter.caloriesRemaining.map(whole) ?? Format.placeholder,
                    label: showsRemaining ? String(localized: "Consumed") : String(localized: "Remaining"),
                    alignment: .center
                )
                .frame(maxWidth: .infinity)

                CalorieGauge(
                    fraction: presenter.caloriesFraction,
                    showsRemaining: showsRemaining,
                    value: showsRemaining ? presenter.caloriesRemaining.map(whole) ?? Format.placeholder : whole(presenter.caloriesConsumed),
                    label: showsRemaining ? String(localized: "Remaining") : String(localized: "Consumed")
                )

                Stat(
                    value: presenter.caloriesTarget.map(whole) ?? Format.placeholder,
                    label: String(localized: "Target"),
                    alignment: .center
                )
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: Spacing.l)
            HStack(spacing: Spacing.l) {
                ForEach(presenter.macroRows) { row in
                    macroBar(row)
                }
            }
        } toggle: {
            CarouselToggle(title: String(localized: "Daily Nutrition"), selection: $presenter.dailyShowsRemaining, options: [false, true]) {
                $0 ? String(localized: "Remaining") : String(localized: "Consumed")
            }
        }
        .reducedMotionAnimation(.standard, value: presenter.dailyShowsRemaining)
    }

    /// Consumed fills from the left; remaining is the rest of the bar, so the two read as halves of
    /// the same target.
    private func macroBar(_ row: ProgressCarouselPresenter.MacroRow) -> some View {
        let amount = showsRemaining
            ? row.target.map { MacroHeader.remaining(total: row.consumed, target: $0, showOverages: false) } ?? 0
            : row.consumed
        let figure = row.target.map { "\(whole(amount)) / \(Format.grams($0))" } ?? Format.grams(amount)
        return VStack(spacing: Spacing.xs) {
            Text(row.macro.title)
                .font(.label)
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: showsRemaining ? .trailing : .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(row.macro.colour)
                        .frame(width: geo.size.width * (showsRemaining ? 1 - row.fraction : row.fraction))
                }
            }
            .frame(height: Spacing.xs)
            Text(figure)
                .font(.metricSmall)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.macro.title)
        .accessibilityValue(figure)
    }
}

/// Three quarters of a circle, open at the foot, filled to how far into the day's calories the
/// user is — or, showing what is left, the part still to eat.
private struct CalorieGauge: View {
    let fraction: Double
    let showsRemaining: Bool
    let value: String
    let label: String

    private static let sweep = 0.75
    private let stroke = StrokeStyle(lineWidth: 8, lineCap: .round)

    var body: some View {
        ZStack {
            arc(from: 0, to: 1).stroke(.quaternary, style: stroke)
            arc(from: showsRemaining ? fraction : 0, to: showsRemaining ? 1 : fraction)
                .stroke(Color.calories, style: stroke)
            VStack(spacing: Spacing.xxs) {
                Text(value)
                    .font(.display)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(label)
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.l)
        }
        .frame(width: 170, height: 170)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    /// Starts at the lower left and runs clockwise over the top.
    private func arc(from start: Double, to end: Double) -> some Shape {
        Circle()
            .trim(from: start * Self.sweep, to: end * Self.sweep)
            .rotation(.degrees(135))
    }
}

// MARK: - Energy balance

struct EnergyBalanceCard: View {
    @Bindable var presenter: ProgressCarouselPresenter

    var body: some View {
        let comparison = presenter.energyComparison
        let averages = presenter.energyAverages
        CarouselPage(title: String(localized: "Energy Balance")) {
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                // `ChartThumbnail` draws at a fixed height (36 pt unless told otherwise), so it is
                // handed whatever height the page has spare.
                GeometryReader { geo in
                    ChartThumbnail(
                        data: [presenter.energyIntakeSeries, presenter.energyComparisonSeries],
                        style: .combo(lineSeries: [presenter.energyComparisonSeries.name]),
                        colors: [EnergyBalanceChart.intakeColor, comparison.colour],
                        height: geo.size.height
                    )
                }
                .frame(minHeight: ChartHeight.compact, maxHeight: .infinity)
                // The highest value sits on the chart's top edge; this keeps it off the title.
                .padding(.top, Spacing.s)
                .accessibilityHidden(true)
                Text("Last \(ProgressCarouselPresenter.energyDayCount) Days")
                    .font(.label)
                    .foregroundStyle(.secondary)
            }

            // Intake − comparison = difference, averaged over the days something was logged.
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Stat(
                    value: averages.map { whole($0.intake) } ?? Format.placeholder,
                    label: String(localized: "Nutrition"),
                    systemImage: "chart.bar.fill",
                    alignment: .center,
                    tint: EnergyBalanceChart.intakeColor
                )
                operatorSign("−")
                Stat(
                    value: averages.map { whole($0.comparison) } ?? Format.placeholder,
                    label: comparison.title,
                    systemImage: "chart.line.uptrend.xyaxis",
                    alignment: .center,
                    tint: comparison.colour
                )
                operatorSign("=")
                Stat(
                    value: averages.map { whole($0.intake - $0.comparison) } ?? Format.placeholder,
                    label: String(localized: "Difference"),
                    alignment: .center
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.l)
        } toggle: {
            CarouselToggle(
                title: String(localized: "Energy Balance"),
                selection: $presenter.energyComparison,
                options: ProgressCarouselPresenter.EnergyComparison.allCases,
                label: \.title
            )
        }
        .reducedMotionAnimation(.standard, value: presenter.energyComparison)
    }

    private func operatorSign(_ sign: String) -> some View {
        Text(verbatim: sign)
            .font(.metric)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }
}

// MARK: - Weekly workouts

struct WeeklyWorkoutsCard: View {
    @Bindable var presenter: ProgressCarouselPresenter

    var body: some View {
        let tally = presenter.workoutTally
        let target = presenter.workoutTarget
        CarouselPage(title: String(localized: "Weekly Workouts")) {
            Spacer(minLength: 0)
            // The middle ring keeps its size; the outer two share what width is left.
            HStack(alignment: .top, spacing: Spacing.s) {
                TallyRing(value: tally.muscles, target: target?.muscles, title: String(localized: "Muscles"), colour: Color.Metric.muscleGroups, diameter: 92)
                    .frame(maxWidth: .infinity)
                TallyRing(value: tally.sets, target: target?.sets, title: String(localized: "Sets"), colour: Color.Metric.workouts, diameter: 136)
                TallyRing(value: tally.exercises, target: target?.exercises, title: String(localized: "Exercises"), colour: Color.Metric.exercises, diameter: 92)
                    .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 0)
        } toggle: {
            // Without a mesocycle there is no program to narrow to, and nothing to aim at.
            if presenter.hasActiveProgram {
                CarouselToggle(
                    title: String(localized: "Weekly Workouts"),
                    selection: $presenter.workoutScope,
                    options: ProgressCarouselPresenter.WorkoutScope.allCases,
                    label: \.title
                )
            }
        }
        .reducedMotionAnimation(.standard, value: presenter.workoutScope)
    }
}

private struct TallyRing: View {
    let value: Int
    let target: Int?
    let title: String
    let colour: Color
    let diameter: CGFloat

    private var fraction: Double {
        guard let target, target > 0 else { return 0 }
        return min(Double(value) / Double(target), 1)
    }

    var body: some View {
        VStack(spacing: Spacing.m) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: fraction)
                    .rotation(.degrees(-90))
                    .stroke(colour, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                VStack(spacing: 0) {
                    Text(value.formatted())
                        .font(.metricLarge)
                    if let target {
                        Text("\(max(target - value, 0)) left")
                            .font(.label)
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(Spacing.m)
            }
            .frame(width: diameter, height: diameter)

            VStack(spacing: Spacing.xxs) {
                Text(title)
                    .font(.rowTitle)
                if let target {
                    Text("\(target) target")
                        .font(.label)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(target.map { String(localized: "\(value) of \($0)") } ?? value.formatted())
    }
}

// MARK: - Recent records

struct RecentRecordsCard: View {
    @Bindable var presenter: ProgressCarouselPresenter

    @ScaledMetric private var nameWidth: CGFloat = 130
    @ScaledMetric private var valueWidth: CGFloat = 90
    @ScaledMetric private var rowHeight: CGFloat = 22

    var body: some View {
        let rows = presenter.recordRows
        CarouselPage(title: String(localized: "Recent Records")) {
            if rows.isEmpty {
                ContentUnavailableView(
                    "No Records Yet",
                    systemImage: Symbol.personalRecord,
                    description: Text("Finish a workout and your best lifts appear here.")
                )
            } else {
                Grid(alignment: .leading, horizontalSpacing: Spacing.m, verticalSpacing: Spacing.m) {
                    ForEach(rows) { row in
                        GridRow {
                            Text(row.name)
                                .lineLimit(1)
                                .frame(width: nameWidth, alignment: .leading)
                            // The figure follows the end of its bar, so the longest bar leaves room for it.
                            GeometryReader { geo in
                                HStack(spacing: Spacing.s) {
                                    Capsule()
                                        .fill(.personalRecord)
                                        .frame(width: max(Spacing.xs, (geo.size.width - valueWidth) * row.fraction), height: Spacing.m)
                                        .accessibilityHidden(true)
                                    Text(row.valueText)
                                        .monospacedDigit()
                                        .fixedSize()
                                }
                                .frame(maxHeight: .infinity)
                            }
                            .frame(height: rowHeight)
                        }
                    }
                }
                .font(.rowDetail)
            }
            Spacer(minLength: 0)
        } toggle: {
            CarouselToggle(
                title: String(localized: "Recent Records"),
                selection: $presenter.recordKind,
                options: ProgressCarouselMetrics.RecordKind.allCases,
                label: \.title
            )
        }
        .reducedMotionAnimation(.standard, value: presenter.recordKind)
    }
}
