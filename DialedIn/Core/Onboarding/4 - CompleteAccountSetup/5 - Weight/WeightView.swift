//
//  WeightView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 04/10/2025.
//

import SwiftUI

struct WeightDelegate {
    let gender: Gender
    let dateOfBirth: Date
    let heightInCentimeters: Double
    let lengthUnitPreference: LengthUnitPreference
    
    init(delegate: HeightDelegate, heightInCentimeters: Double, lengthUnitPreference: LengthUnitPreference) {
        self.gender = delegate.gender
        self.dateOfBirth = delegate.dateOfBirth
        self.heightInCentimeters = heightInCentimeters
        self.lengthUnitPreference = lengthUnitPreference
    }
    
    static var mock: Self {
        Self(delegate: .mock, heightInCentimeters: 180, lengthUnitPreference: .centimeters)
    }
}

struct WeightView: View {

    @State var presenter: WeightPresenter

    var delegate: WeightDelegate

    var body: some View {
        OnboardingStepScaffold(
            title: "What's Your Weight?",
            subtitle: "Your weight feeds the calorie estimate and your goal. You can log a new weight at any time.",
            progress: OnboardingStep.completeAccountSetup.progress,
            primary: .init(title: "Continue", identifier: "Continue") { presenter.onContinuePressed(delegate: delegate) },
            onDevSettingsPressed: nil
        ) {
            AppleHealthFillSection(state: presenter.healthFill, action: presenter.onFillFromAppleHealthPressed)
            pickerSection
            if presenter.unit == .kilograms {
                metricSection
            } else {
                imperialSection
            }
        }
        .onAppear { presenter.onAppear(delegate: delegate) }
    }

    private var pickerSection: some View {
        Section {
            Picker("Units", selection: $presenter.unit) {
                Text("Metric").tag(UnitOfWeight.kilograms)
                Text("Imperial").tag(UnitOfWeight.pounds)
            }
            .pickerStyle(.segmented)
        }
        .removeListRowFormatting()
    }

    private var metricSection: some View {
        Section {
            Picker("Kilograms", selection: $presenter.selectedKilograms) {
                ForEach(WeightPresenter.kilogramsRange, id: \.self) { value in
                    Text("\(value) kg").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .onChange(of: presenter.selectedKilograms) { _, _ in
                presenter.updatePoundsFromKilograms()
            }
        } header: {
            Text("Metric")
        }
        .removeListRowFormatting()
    }

    private var imperialSection: some View {
        Section {
            Picker("Pounds", selection: $presenter.selectedPounds) {
                ForEach(WeightPresenter.poundsRange, id: \.self) { value in
                    Text("\(value) lb").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .onChange(of: presenter.selectedPounds) { _, _ in
                presenter.updateKilogramsFromPounds()
            }
        } header: {
            Text("Imperial")
        }
        .removeListRowFormatting()
    }

}

extension CoreBuilder {
    func weightView(router: AnyRouter, delegate: WeightDelegate) -> some View {
        WeightView(
            presenter: WeightPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showWeightView(delegate: WeightDelegate) {
        router.showScreen(.push) { router in
            builder.weightView(router: router, delegate: delegate)
        }
    }

}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.weightView(
            router: router,
            delegate: .mock
        )
    }
    
}
