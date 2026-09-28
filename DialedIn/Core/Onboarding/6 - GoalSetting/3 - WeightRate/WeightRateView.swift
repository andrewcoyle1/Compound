//
//  WeightRateView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 05/10/2025.
//

import SwiftUI

struct WeightRateDelegate {
    let overarchingObjective: OverarchingObjective
    let targetWeight: Double
    
    init(delegate: TargetWeightDelegate, targetWeight: Double) {
        self.overarchingObjective = delegate.overarchingObjective
        self.targetWeight = targetWeight
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
            onDevSettingsPressed: onDevSettingsPressed
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
    }

    private var rateSelectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(presenter.currentRateCategory.title)
                    .font(.sectionTitle)

                Slider(
                    value: $presenter.weightChangeRate,
                    in: presenter.minWeightChangeRate...presenter.maxWeightChangeRate,
                    step: 0.05
                ) {
                    Text("Weekly rate")
                } minimumValueLabel: {
                    Text(presenter.minWeightChangeRate, format: .number.precision(.fractionLength(1)))
                } maximumValueLabel: {
                    Text(presenter.maxWeightChangeRate, format: .number.precision(.fractionLength(1)))
                }
                .font(.label)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, Spacing.xs)
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
            Text(presenter.estimatedEndDateText(delegate: delegate))
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

    private var onDevSettingsPressed: (() -> Void)? {
        #if DEV || MOCK
        presenter.onDevSettingsPressed
        #else
        nil
        #endif
    }
}

extension CoreBuilder {
    func weightRateView(router: AnyRouter, delegate: WeightRateDelegate) -> some View {
        WeightRateView(
            presenter: WeightRatePresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
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
