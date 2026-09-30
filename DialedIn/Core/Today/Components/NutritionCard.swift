import SwiftUI

struct NutritionCard: View {
    
    let calories: Double
    let calorieTarget: Double
    let proteinGrams: Double
    let proteinTarget: Double
    let carbGrams: Double
    let carbTarget: Double
    let fatGrams: Double
    let fatTarget: Double
    let onLogMealTapped: () -> Void
    
    var body: some View {
        Section {
            cardItem
        } header: {
            SectionHeaderView(title: "Today's Nutrition", actionTitle: "Log Meal", padsEdges: false, onActionPressed: onLogMealTapped)
        }
    }
    
    private var cardItem: some View {
        VStack(spacing: Spacing.l) {
            AdaptiveStack(horizontalAlignment: .leading, spacing: Spacing.xl) {
                ActivityRingView(
                    text: calories.formatted(.number.precision(.fractionLength(0))),
                    imageName: Symbol.calories + ".fill",
                    progress: calorieTarget > 0 ? min(calories / calorieTarget, 1) : 0,
                    color: .calories,
                    size: 80
                )
                
                VStack(alignment: .leading, spacing: Spacing.s) {
                    macroBar(label: String(localized: "Protein"), value: proteinGrams, target: proteinTarget, color: .protein)
                    macroBar(label: String(localized: "Carbs"), value: carbGrams, target: carbTarget, color: .carbs)
                    macroBar(label: String(localized: "Fat"), value: fatGrams, target: fatTarget, color: .fat)
                }
                .frame(maxWidth: .infinity)
            }
            
            if calorieTarget > 0 {
                HStack {
                    Text(verbatim: "\(calories.formatted(.number.precision(.fractionLength(0)))) / \(Format.kcal(calorieTarget))")
                        .font(.label)
                        .foregroundStyle(.secondary)
                    Spacer()
                    let remaining = calorieTarget - calories
                    if remaining > 0 {
                        Text("\(Format.kcal(remaining)) remaining")
                            .font(.label)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Goal reached!", systemImage: Symbol.success)
                            .font(.label)
                            .foregroundStyle(.success)
                    }
                }
            }
        }
    }
    
    private func macroBar(label: String, value: Double, target: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Text(label)
                    .font(.label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Format.grams(value))
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: target > 0 ? min(value / target, 1) : 0)
                .tint(color)
        }
    }
}

#Preview {
    List {
        NutritionCard(
            calories: 1450,
            calorieTarget: 2200,
            proteinGrams: 110,
            proteinTarget: 150,
            carbGrams: 180,
            carbTarget: 250,
            fatGrams: 45,
            fatTarget: 70,
            onLogMealTapped: {}
        )
    }
}
