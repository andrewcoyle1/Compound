//
//  DietPlanView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 06/10/2025.
//

import SwiftUI

struct DietPlanDelegate {
    let preferredDiet: PreferredDiet
    let calorieFloor: CalorieFloor
    let calorieDistribution: CalorieDistribution
    let proteinIntake: ProteinIntake
    var isFromSettings: Bool

    init(
        preferredDiet: PreferredDiet,
        calorieFloor: CalorieFloor,
        calorieDistribution: CalorieDistribution,
        proteinIntake: ProteinIntake,
        isFromSettings: Bool
    ) {
        self.preferredDiet = preferredDiet
        self.calorieFloor = calorieFloor
        self.calorieDistribution = calorieDistribution
        self.proteinIntake = proteinIntake
        self.isFromSettings = isFromSettings
    }

    init(oldDelegate delegate: ProteinIntakeDelegate, proteinIntake: ProteinIntake) {
        self.preferredDiet = delegate.preferredDiet
        self.calorieFloor = delegate.calorieFloor
        self.calorieDistribution = delegate.calorieDistrubtion
        self.proteinIntake = proteinIntake
        self.isFromSettings = delegate.isFromSettings
    }
    
    static var mock: Self {
        Self(oldDelegate: .mock, proteinIntake: .moderate)
    }
}

struct DietPlanView: View {

    @State var presenter: DietPlanPresenter

    var delegate: DietPlanDelegate

    var body: some View {
        OnboardingStepScaffold(
            title: "Happy With This?",
            progress: delegate.isFromSettings ? nil : OnboardingStep.customiseProgram.progress,
            primary: .init(title: "Continue", identifier: "Continue") { presenter.navigate() },
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            if let plan = presenter.plan {
                chartSection(plan)
                overviewSection(plan)
                weeklyBreakdownSection(plan)
            } else {
                Section {
                    Text("Generating your plan…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            presenter.createPlan(delegate: delegate)
        }
    }

    private func chartSection(_ plan: DietPlan) -> some View {
        Section("Weekly Calorie & Macro Breakdown") {
            WeeklyMacroChart(plan: plan)
        }
    }

    private func overviewSection(_ plan: DietPlan) -> some View {
        Section("Overview") {
            if let programName = presenter.trainingProgramName,
               let daysPerWeek = presenter.trainingDaysPerWeek {
                Text("Training program: \(programName), \(daysPerWeek) days/week")
            }
            Text("Estimated TDEE: \(Int(plan.tdeeEstimate)) kcal/day")
            Text("Preferred diet: \(plan.preferredDiet.capitalized)")
            Text("Calorie floor: \(plan.calorieFloor.capitalized)")
            Text("Training focus: \(plan.trainingType.replacingOccurrences(of: "_", with: " ").capitalized)")
            Text("Distribution: \(plan.calorieDistribution.capitalized)")
            Text("Protein: \(plan.proteinIntake.capitalized)")
        }
        .font(.rowDetail)
        .foregroundStyle(.secondary)
    }

    private func weeklyBreakdownSection(_ plan: DietPlan) -> some View {
        Section("7-day targets") {
            ForEach(Array(plan.days.enumerated()), id: \.offset) { idx, day in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Day \(idx + 1)")
                        .font(.sectionTitle)
                    HStack(spacing: Spacing.l) {
                        labelValue("Calories", Format.kcal(day.calories))
                        labelValue("Protein", Format.grams(day.proteinGrams))
                    }
                    HStack(spacing: Spacing.l) {
                        labelValue("Carbs", Format.grams(day.carbGrams))
                        labelValue("Fat", Format.grams(day.fatGrams))
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
        }
    }

    private func labelValue(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.rowDetail)
    }

    private var onDevSettingsPressed: (() -> Void)? {
        #if DEV || MOCK
        presenter.onDevSettingsPressed
        #else
        nil
        #endif
    }
}

extension CoreBuilder {
    func dietPlanView(router: AnyRouter, delegate: DietPlanDelegate) -> some View {
        DietPlanView(
            presenter: DietPlanPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showDietPlanView(delegate: DietPlanDelegate) {
        router.showScreen(.push) { router in
            builder.dietPlanView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.dietPlanView(
            router: router,
            delegate: .mock
        )
    }
    
}
