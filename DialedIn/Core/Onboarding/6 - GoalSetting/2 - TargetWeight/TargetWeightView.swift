//
//  TargetWeightView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 05/10/2025.
//

import SwiftUI

struct TargetWeightDelegate {
    let overarchingObjective: OverarchingObjective
    
    static func mock(overarchingObjective: OverarchingObjective) -> Self {
        Self(overarchingObjective: overarchingObjective)
    }
}

struct TargetWeightView: View {

    @State var presenter: TargetWeightPresenter

    var delegate: TargetWeightDelegate

    var body: some View {
        OnboardingStepScaffold(
            title: "What's Your Target?",
            progress: presenter.isStandaloneMode ? nil : OnboardingStep.goalSetting.progress,
            primary: .init(title: "Continue", isEnabled: presenter.canContinue, identifier: "Continue") { presenter.onContinuePressed(delegate: delegate) },
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            if presenter.didInitialize && presenter.weightUnit == .kilograms {
                kilogramsSection
            } else if presenter.didInitialize {
                poundsSection
            } else {
                loadingSection
            }
        }
        .onFirstAppear {
            presenter.onAppear(delegate: delegate)
        }
    }

    private var kilogramsSection: some View {
        Section {
            Picker("Kilograms", selection: $presenter.selectedKilograms) {
                ForEach(presenter.kilogramRange(delegate: delegate), id: \.self) { value in
                    Text("\(value) kg").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .onChange(of: presenter.selectedKilograms) { _, _ in
                presenter.updateFromKilograms()
            }
        } header: {
            Text("Metric")
        }
        .removeListRowFormatting()
    }

    private var poundsSection: some View {
        Section {
            Picker("Pounds", selection: $presenter.selectedPounds) {
                ForEach(presenter.poundRange(delegate: delegate), id: \.self) { value in
                    Text("\(value) lb").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .onChange(of: presenter.selectedPounds) { _, _ in
                presenter.updateFromPounds()
            }
        } header: {
            Text("Imperial")
        }
        .removeListRowFormatting()
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
    func targetWeightView(router: AnyRouter, delegate: TargetWeightDelegate) -> some View {
        TargetWeightView(
            presenter: TargetWeightPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showTargetWeightView(delegate: TargetWeightDelegate) {
        router.showScreen(.push) { router in
            builder.targetWeightView(router: router, delegate: delegate)
        }
    }
}

#Preview("Gain Weight") {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.targetWeightView(
            router: router,
            delegate: .mock(overarchingObjective: .gainWeight)
        )
    }
    
}

#Preview("Lose Weight") {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.targetWeightView(
            router: router,
            delegate: .mock(overarchingObjective: .loseWeight)
        )
    }
    
}
