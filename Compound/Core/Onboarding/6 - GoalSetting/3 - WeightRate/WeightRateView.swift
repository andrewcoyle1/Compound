//
//  WeightRateView.swift
//  Compound
//
//  Created by Andrew Coyle on 05/10/2025.
//

import SwiftUI

struct WeightRateDelegate {
    let overarchingObjective: OverarchingObjective
    let targetWeight: Double
    let isStandaloneMode: Bool
    let editingGoal: WeightGoal?
    
    init(delegate: TargetWeightDelegate, targetWeight: Double) {
        self.overarchingObjective = delegate.overarchingObjective
        self.targetWeight = targetWeight
        self.isStandaloneMode = delegate.isStandaloneMode
        self.editingGoal = delegate.editingGoal
    }
    
    static func mock(overarchingObjective: OverarchingObjective) -> Self {
        Self(delegate: .mock(overarchingObjective: overarchingObjective), targetWeight: 60)
    }
}

struct WeightRateView: View {

    @State var presenter: WeightRatePresenter

    var delegate: WeightRateDelegate

    var body: some View {
        OnboardingStepScaffold(
            title: "At What Rate?",
            progress: presenter.isStandaloneMode ? nil : OnboardingStep.goalSetting.progress,
            primary: .init(title: "Continue", identifier: "Continue") { presenter.onContinuePressed(delegate: delegate) },
            onDevSettingsPressed: nil
        ) {
            if presenter.didInitialize {
                rateSelectionSection
                rateDetailsSection
                additionalInfoSection
            } else {
                loadingSection
            }
        }
        .onFirstAppear {
            presenter.onAppear(delegate: delegate)
        }
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
    }

    private var rateSelectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(presenter.currentRateCategory.title)
                    .font(.sectionTitle)

                HStack(spacing: Spacing.s) {
                    Slider(
                        value: $presenter.weightChangeRate,
                        in: presenter.minWeightChangeRate...presenter.maxWeightChangeRate,
                        step: 0.05
                    ) {
                        Text("Weekly rate")
                    } minimumValueLabel: {
                        Text(Format.weight(kg: presenter.minWeightChangeRate, unit: presenter.weightUnit, maximumFractionDigits: 2))
                    } maximumValueLabel: {
                        Text(Format.weight(kg: presenter.maxWeightChangeRate, unit: presenter.weightUnit, maximumFractionDigits: 2))
                    }
                    .accessibilityValue(presenter.weeklyWeightChangeText(delegate: delegate))

                    Stepper(
                        "Weekly rate",
                        value: $presenter.weightChangeRate,
                        in: presenter.minWeightChangeRate...presenter.maxWeightChangeRate,
                        step: 0.05
                    )
                    .labelsHidden()
                }
                .font(.label)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, Spacing.xs)

            if let warning = presenter.rateWarningText(delegate: delegate) {
                InlineMessage(.warning, warning)
            }
        } header: {
            MethodInfoHeader(title: "Weekly Rate", info: .weightChangeRate)
        }
    }

    private var rateDetailsSection: some View {
        Section {
            Text(presenter.weeklyWeightChangeText(delegate: delegate))
            Text(presenter.monthlyWeightChangeText(delegate: delegate))
        }
        .fontWeight(.medium)
    }

    private var additionalInfoSection: some View {
        Section {
            Text(presenter.estimatedCalorieTargetText(delegate: delegate))
            if let capText = presenter.deficitCapText(delegate: delegate) {
                Text(capText)
            }
            Text(presenter.estimatedEndDateText(delegate: delegate))
            if let stepText = presenter.targetStepText(delegate: delegate) {
                Text(stepText)
            }
        } header: {
            MethodInfoHeader(title: "Target and Timeline", info: .goalTimeline)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    private var loadingSection: some View {
        Section {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxl)
        }
        .removeListRowFormatting()
    }

}

extension CoreBuilder {
    func weightRateView(router: AnyRouter, delegate: WeightRateDelegate) -> some View {
        WeightRateView(
            presenter: WeightRatePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                isStandaloneMode: delegate.isStandaloneMode
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showWeightRateView(delegate: WeightRateDelegate) {
        router.showScreen(.push) { router in
            builder.weightRateView(router: router, delegate: delegate)
        }
    }
}

#Preview("Gain Weight") {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.weightRateView(
            router: router,
            delegate: .mock(overarchingObjective: .gainWeight)
        )
    }
    
}

#Preview("Lose Weight") {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.weightRateView(
            router: router,
            delegate: .mock(overarchingObjective: .loseWeight)
        )
    }
    
}
