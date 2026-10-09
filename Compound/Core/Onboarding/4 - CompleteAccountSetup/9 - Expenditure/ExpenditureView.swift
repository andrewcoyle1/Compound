//
//  ExpenditureView.swift
//  Compound
//
//  Created by Andrew Coyle on 05/10/2025.
//

import SwiftUI

struct ExpenditureDelegate {
    let gender: Gender
    let dateOfBirth: Date
    let heightInCentimetres: Double
    let lengthUnitPreference: LengthUnitPreference
    let weightInKilograms: Double
    let weightUnitPreference: WeightUnitPreference
    let exerciseFrequency: ExerciseFrequency
    let activityLevel: ActivityLevel

    init(delegate: ActivityDelegate, activityLevel: ActivityLevel) {
        self.gender = delegate.gender
        self.dateOfBirth = delegate.dateOfBirth
        self.heightInCentimetres = delegate.heightInCentimetres
        self.lengthUnitPreference = delegate.lengthUnitPreference
        self.weightInKilograms = delegate.weightInKilograms
        self.weightUnitPreference = delegate.weightUnitPreference
        self.exerciseFrequency = delegate.exerciseFrequency
        self.activityLevel = activityLevel
    }

    static var mock: Self {
        Self(delegate: .mock, activityLevel: .active)
    }

}

struct ExpenditureView: View {

    @State var presenter: ExpenditurePresenter

    var delegate: ExpenditureDelegate

    var body: some View {
        OnboardingStepScaffold(
            title: "How Much Do You Burn?",
            progress: OnboardingStep.completeAccountSetup.progress,
            primary: .init(title: "Continue", isEnabled: presenter.canContinue, identifier: "Continue") { presenter.onContinuePressed(delegate: delegate) },
            onDevSettingsPressed: nil
        ) {
            overviewSection
            breakdownSection
            explanationSection
        }
        .scrollIndicators(.hidden)
        .onFirstAppear {
            presenter.estimateExpenditure(delegate: delegate)
        }
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
    }

    private var overviewSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(presenter.displayedKcal, format: .number)
                    .font(.display)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("kcal/day")
                    .font(.sectionTitle)
                    .foregroundStyle(.secondary)
            }
        } header: {
            MethodInfoHeader(title: "An estimate of calories burned per day", info: .formulaExpenditure)
        } footer: {
            Text("This is your estimated total daily energy expenditure. Formulas like this are typically within about 10% for three people in four, so Compound refines it from your own logs once you start tracking.")
        }
    }
    
    private var breakdownItems: [ExpenditurePresenter.Breakdown] {
        
        let context = ExpenditurePresenter.ExpenditureContext(
            weight: delegate.weightInKilograms,
            height: delegate.heightInCentimetres,
            dateOfBirth: delegate.dateOfBirth,
            gender: delegate.gender,
            activityLevel: delegate.activityLevel
        )
        return presenter.breakdownItems(context: context)
    }
    
    private var breakdownSection: some View {
        Section {
            ForEach(breakdownItems) { item in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack {
                        Text(item.name)
                            .font(.rowDetail)
                        Spacer()
                        Text(Format.kcal(Double(item.calories)))
                            .font(.rowDetail)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: presenter.animateBreakdown ? presenter.progress(for: item) : 0)
                        .tint(item.color)
                        .reducedMotionAnimation(.progress, value: presenter.animateBreakdown)
                }
                .padding(.vertical, Spacing.xs)
            }
        } header: {
            MethodInfoHeader(title: "Breakdown", info: .thermicEffectOfFood)
        }
    }
    
    // MARK: - Explanation
    private var explanationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack {
                    Text("Resting Calories")
                    Spacer()
                    Text(Format.kcal(Double(calculatedBmrInt)))
                        .foregroundStyle(.secondary)
                }
                Divider()
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Physical Activity Level")
                        Text(activityDescriptionText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("× \(calculatedBaseActivityMultiplier, format: .number.precision(.fractionLength(2)))")
                        .foregroundStyle(.secondary)
                }
                Divider()
                HStack {
                    Text("Daily Calories Burned")
                    Spacer()
                    Text("Resting calories × activity level")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(Format.kcal(Double(calculatedTdeeInt)))/day")
                        .fontWeight(.semibold)
                }
            }
        } header: {
            MethodInfoHeader(title: "How This Is Calculated", info: .restingMetabolicRate)
        } footer: {
            Text("Resting calories come from the Mifflin-St Jeor equation, using your age, height, weight and sex. They're then multiplied by a physical activity level that already includes your workouts. A calorie floor is applied when your targets are set.")
        }
    }
    
    private var calculatedBmrInt: Int {

        return presenter.bmrInt(
            weight: delegate.weightInKilograms,
            height: delegate.heightInCentimetres,
            dateOfBirth: delegate.dateOfBirth,
            gender: delegate.gender
        )
    }
    
    private var activityDescriptionText: String {
        
        return presenter.activityDescription(activityLevel: delegate.activityLevel)
    }
    
    private var calculatedBaseActivityMultiplier: Double {
        return presenter.baseActivityMultiplier(activityLevel: delegate.activityLevel)
    }
    
    private var calculatedTdeeInt: Int {

        let context = ExpenditurePresenter.ExpenditureContext(
            weight: delegate.weightInKilograms,
            height: delegate.heightInCentimetres,
            dateOfBirth: delegate.dateOfBirth,
            gender: delegate.gender,
            activityLevel: delegate.activityLevel
        )
        return presenter.tdeeInt(context: context)
    }
}

extension CoreBuilder {
    func expenditureView(router: AnyRouter, delegate: ExpenditureDelegate) -> some View {
        ExpenditureView(
            presenter: ExpenditurePresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showExpenditureView(delegate: ExpenditureDelegate) {
        router.showScreen(.push) { router in
            builder.expenditureView(router: router, delegate: delegate)
        }
    }

}

#Preview("Functioning") {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.expenditureView(
            router: router, 
            delegate: .mock
        )
    }
    
}
