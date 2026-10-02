import SwiftUI

struct NutritionOverviewDelegate {
    var dayKey: String = Date().dayKey
    var eventParameters: [String: Any]? { nil }
}

struct NutritionOverviewView: View {

    @State var presenter: NutritionOverviewPresenter
    let delegate: NutritionOverviewDelegate

    var body: some View {
        List {
            checkInSection
            proposalSection
            caloriesSection
            contributorsSection
            macrosSection
            nutrientSection("Carb Breakdown", carbs)
            nutrientSection("Fat Breakdown", fats)
            nutrientSection("Vitamins", vitamins)
            nutrientSection("Minerals", minerals)
            nutrientSection("Other", other)
        }
        .navigationTitle("Nutrition Overview")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    // MARK: - Weekly check-in

    /// Takes the proposal card's place while a check-in is due, because the proposal is the
    /// check-in's last step: two cards offering the same decision, one of them without the week's
    /// context, is how a considered change turns into a stray tap.
    @ViewBuilder
    private var checkInSection: some View {
        if presenter.dueCheckInWeekStart != nil {
            Section {
                decisionCard(
                    title: "Weekly check-in ready",
                    message: Text("Review the week and update your program."),
                    primary: ("Start", presenter.onStartCheckInPressed),
                    secondary: ("Skip This Week", presenter.onSkipCheckInPressed)
                )
            }
        }
    }

    // MARK: - Target proposal

    /// Deliberately plain. The weekly check-in flow will give this a proper home and a proper
    /// look; until then it is two buttons and a sentence, which is enough to make the engine's
    /// output actionable without pretending to be the finished feature.
    @ViewBuilder
    private var proposalSection: some View {
        if let summary = presenter.proposalSummary, presenter.dueCheckInWeekStart == nil {
            Section {
                decisionCard(
                    title: "New targets suggested",
                    message: Text(summary),
                    primary: ("Accept", presenter.onAcceptProposalPressed),
                    secondary: ("Not now", presenter.onDismissProposalPressed)
                )
            }
        }
    }

    private func decisionCard(
        title: LocalizedStringKey,
        message: Text,
        primary: (LocalizedStringKey, () -> Void),
        secondary: (LocalizedStringKey, () -> Void)
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(.sectionTitle)
            message
                .font(.rowDetail)
                .foregroundStyle(.secondary)
            HStack(spacing: Spacing.m) {
                Button(action: primary.1) {
                    Text(primary.0)
                        .foregroundStyle(.onAccent)
                }
                .buttonStyle(.borderedProminent)
                Button(secondary.0, action: secondary.1)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Calories

    private var caloriesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Format.kcal(presenter.totals.calories)) consumed")
                        .font(.sectionTitle)
                    Spacer()
                    if let target = presenter.target {
                        Text("/ \(Format.kcal(target.calories))")
                            .foregroundStyle(.secondary)
                    }
                }
                .monospacedDigit()
                ProgressView(value: presenter.caloriesProgress)
                    .tint(.calories)
            }
            .padding(.vertical, Spacing.xs)
        } header: {
            HStack {
                Text("Calories")
                Spacer()
                Toggle(isOn: $presenter.showsContributors) {
                    Text("Contributors")
                        .font(.rowDetail)
                }
                .fixedSize()
            }
        }
    }

    // MARK: - Contributors

    @ViewBuilder
    private var contributorsSection: some View {
        if presenter.showsContributors && !presenter.topContributors.isEmpty {
            Section("Top Contributors") {
                ForEach(presenter.topContributors) { contributor in
                    ListRow(
                        title: contributor.displayName,
                        subtitle: [
                            String(localized: "\(Format.grams(contributor.proteinGrams)) P"),
                            String(localized: "\(Format.grams(contributor.fatGrams)) F"),
                            String(localized: "\(Format.grams(contributor.carbGrams)) C")
                        ].joined(separator: " · "),
                        accessory: .value(Format.kcal(contributor.calories))
                    )
                }
            }
        }
    }

    // MARK: - Macros

    private var macrosSection: some View {
        Section {
            macroRow(.protein, grams: presenter.totals.proteinGrams, target: presenter.target?.proteinGrams, progress: presenter.proteinProgress)
            macroRow(.carbs, grams: presenter.totals.carbGrams, target: presenter.target?.carbGrams, progress: presenter.carbsProgress)
            macroRow(.fat, grams: presenter.totals.fatGrams, target: presenter.target?.fatGrams, progress: presenter.fatProgress)
        } header: {
            Text("Macros")
        }
    }

    private func macroRow(_ macro: Macro, grams: Double, target: Double?, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(macro.title)
                Spacer()
                Text(grams > 0 ? Format.grams(grams) : Format.placeholder)
                    .foregroundStyle(.secondary)
                if let target {
                    Text("/ \(Format.grams(target))")
                        .font(.label)
                        .foregroundStyle(.tertiary)
                }
            }
            .monospacedDigit()
            ProgressView(value: progress)
                .tint(macro.colour)
        }
        .padding(.vertical, Spacing.xxs)
    }

    // MARK: - Nutrient breakdowns

    /// A section of the nutrients the day has figures for; none, and the section is left out.
    @ViewBuilder
    private func nutrientSection(_ title: LocalizedStringKey, _ items: [NutrientAmount]) -> some View {
        let available = items.filter { $0.value != nil }
        if !available.isEmpty {
            Section(title) {
                ForEach(available, id: \.name) { nutrient in
                    LabeledContent(nutrient.name, value: nutrient.formattedValue)
                        .monospacedDigit()
                }
            }
        }
    }

    private var carbs: [NutrientAmount] {
        let breakdown = presenter.breakdown
        return [
            NutrientAmount(name: String(localized: "Fiber"), value: breakdown.fiberGrams, unit: "g"),
            NutrientAmount(name: String(localized: "Sugar"), value: breakdown.sugarGrams, unit: "g"),
            NutrientAmount(name: String(localized: "Net Carbs"), value: breakdown.netCarbsGrams, unit: "g")
        ]
    }

    private var fats: [NutrientAmount] {
        let breakdown = presenter.breakdown
        return [
            NutrientAmount(name: String(localized: "Saturated"), value: breakdown.fatSaturatedGrams, unit: "g"),
            NutrientAmount(name: String(localized: "Monounsaturated"), value: breakdown.fatMonounsaturatedGrams, unit: "g"),
            NutrientAmount(name: String(localized: "Polyunsaturated"), value: breakdown.fatPolyunsaturatedGrams, unit: "g")
        ]
    }

    private var vitamins: [NutrientAmount] {
        let breakdown = presenter.breakdown
        return [
            NutrientAmount(name: String(localized: "Vitamin A"), value: breakdown.vitaminAMcg, unit: "mcg"),
            NutrientAmount(name: String(localized: "Vitamin B6"), value: breakdown.vitaminB6Mg, unit: "mg"),
            NutrientAmount(name: String(localized: "Vitamin B12"), value: breakdown.vitaminB12Mcg, unit: "mcg"),
            NutrientAmount(name: String(localized: "Vitamin C"), value: breakdown.vitaminCMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Vitamin D"), value: breakdown.vitaminDMcg, unit: "mcg"),
            NutrientAmount(name: String(localized: "Vitamin E"), value: breakdown.vitaminEMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Vitamin K"), value: breakdown.vitaminKMcg, unit: "mcg"),
            NutrientAmount(name: String(localized: "Thiamin"), value: breakdown.thiaminMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Riboflavin"), value: breakdown.riboflavinMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Niacin"), value: breakdown.niacinMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Pantothenic Acid"), value: breakdown.pantothenicAcidMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Folate"), value: breakdown.folateMcg, unit: "mcg")
        ]
    }

    private var minerals: [NutrientAmount] {
        let breakdown = presenter.breakdown
        return [
            NutrientAmount(name: String(localized: "Sodium"), value: breakdown.sodiumMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Potassium"), value: breakdown.potassiumMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Calcium"), value: breakdown.calciumMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Iron"), value: breakdown.ironMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Magnesium"), value: breakdown.magnesiumMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Zinc"), value: breakdown.zincMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Copper"), value: breakdown.copperMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Manganese"), value: breakdown.manganeseMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Phosphorus"), value: breakdown.phosphorusMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Selenium"), value: breakdown.seleniumMcg, unit: "mcg")
        ]
    }

    private var other: [NutrientAmount] {
        let breakdown = presenter.breakdown
        return [
            NutrientAmount(name: String(localized: "Cholesterol"), value: breakdown.cholesterolMg, unit: "mg"),
            NutrientAmount(name: String(localized: "Caffeine"), value: breakdown.caffeineMg, unit: "mg")
        ]
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = NutritionOverviewDelegate()

    return RouterView { router in
        builder.nutritionOverviewView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func nutritionOverviewView(router: AnyRouter, delegate: NutritionOverviewDelegate) -> some View {
        NutritionOverviewView(
            presenter: NutritionOverviewPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showNutritionOverviewView(delegate: NutritionOverviewDelegate) {
        router.showScreen(.push) { router in
            builder.nutritionOverviewView(router: router, delegate: delegate)
        }
    }

}
