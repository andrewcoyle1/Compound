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
        DashboardCard(title: String(localized: "Today's Nutrition")) {
            cardItem
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
            
            Button(action: onLogMealTapped) {
                Text("Log a Meal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
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
        Section {
            TabView {
                Tab {
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
                Tab {
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
                Tab {
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
            .tabViewStyle(.page)
        }
        .frame(height: 240)
        .listSectionMargins(.horizontal, 0)
        .removeListRowFormatting()
        .listRowSeparator(.hidden)
    }
}
