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
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 24) {
                ActivityRingView(
                    text: "\(Int(calories))",
                    imageName: "flame.fill",
                    progress: calorieTarget > 0 ? min(calories / calorieTarget, 1) : 0,
                    color: .orange,
                    size: 80
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    macroBar(label: "Protein", value: proteinGrams, target: proteinTarget, color: .blue)
                    macroBar(label: "Carbs", value: carbGrams, target: carbTarget, color: .green)
                    macroBar(label: "Fat", value: fatGrams, target: fatTarget, color: .yellow)
                }
                .frame(maxWidth: .infinity)
            }
            
            if calorieTarget > 0 {
                HStack {
                    Text("\(Int(calories)) / \(Int(calorieTarget)) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    let remaining = calorieTarget - calories
                    Text(remaining > 0 ? String(localized: "\(String(describing: Int(remaining))) remaining") : String(localized: "Goal reached!"))
                        .font(.caption)
                        .foregroundStyle(remaining > 0 ? Color.secondary : Color.orange)
                }
            }
            
            Button(action: onLogMealTapped) {
                Text("Log a Meal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func macroBar(label: String, value: Double, target: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value))g")
                    .font(.caption2)
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
