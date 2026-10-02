//
//  WeeklyMacroChart.swift
//  Compound
//
//  Created by Andrew Coyle on 06/10/2025.
//

import SwiftUI

/// The diet plan's week as stacked calorie bars: protein at the bottom, then carbs, then fat.
struct WeeklyMacroChart: View {
    let plan: DietPlan

    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let maxCalories: Double

    init(plan: DietPlan) {
        self.plan = plan
        self.maxCalories = plan.days.map { $0.calories }.max() ?? 2000
    }

    private var averageCalories: Double {
        plan.days.map { $0.calories }.reduce(0, +) / 7
    }

    var body: some View {
        VStack(spacing: Spacing.l) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily Calorie Distribution")
                    .font(.sectionTitle)
                Spacer()
                Text("Avg: \(Format.kcal(averageCalories))")
                    .font(.label)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: Spacing.m) {
                ForEach(Array(plan.days.enumerated()), id: \.offset) { index, day in
                    VStack(spacing: Spacing.xs) {
                        VStack(spacing: Spacing.xxs) {
                            bar(.fat, calories: day.fatGrams * 9)
                            bar(.carbs, calories: day.carbGrams * 4)
                            bar(.protein, calories: day.proteinGrams * 4)
                        }
                        .frame(maxWidth: 40)

                        Text(dayNames[index])
                            .font(.label)
                            .foregroundStyle(.secondary)
                        Text(day.calories, format: .number.precision(.fractionLength(0)))
                            .font(.label)
                            .fontWeight(.semibold)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(dayNames[index])
                    .accessibilityValue(summary(day))
                }
            }
            .padding(.horizontal, Spacing.s)

            HStack(spacing: Spacing.xl) {
                LegendItem(color: .protein, label: "Protein")
                LegendItem(color: .carbs, label: "Carbs")
                LegendItem(color: .fat, label: "Fat")
            }
            .accessibilityHidden(true)
        }
    }

    private func bar(_ color: Color, calories: Double) -> some View {
        RoundedRectangle(cornerRadius: Radius.s / 2, style: .continuous)
            .fill(color)
            .frame(height: barHeight(for: calories))
    }

    private func summary(_ day: DailyMacroTarget) -> String {
        [
            Format.kcal(day.calories),
            String(localized: "Protein \(Format.grams(day.proteinGrams))"),
            String(localized: "Carbs \(Format.grams(day.carbGrams))"),
            String(localized: "Fat \(Format.grams(day.fatGrams))")
        ].joined(separator: ", ")
    }

    private func barHeight(for calories: Double) -> CGFloat {
        max(Spacing.xs, (calories / maxCalories) * ChartHeight.regular)
    }
}

private struct LegendItem: View {
    let color: Color
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: Spacing.s) {
            RoundedRectangle(cornerRadius: Radius.s / 2, style: .continuous)
                .fill(color)
                .frame(width: Spacing.l, height: Spacing.l)
            Text(label)
                .font(.label)
        }
    }
}

#Preview {
    let samplePlan = DietPlan(
        planId: "sample",
        userId: nil,
        createdAt: Date(),
        tdeeEstimate: 2200,
        preferredDiet: "balanced",
        calorieFloor: "standard",
        trainingType: "weightlifting",
        calorieDistribution: "varied",
        proteinIntake: "moderate",
        days: DailyMacroTarget.mocks
    )
    
    WeeklyMacroChart(plan: samplePlan)
        .padding()
}
