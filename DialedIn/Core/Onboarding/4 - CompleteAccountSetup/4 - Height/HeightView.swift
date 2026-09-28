//
//  HeightView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 04/10/2025.
//

import SwiftUI

struct HeightDelegate {
    let gender: Gender
    let dateOfBirth: Date
    
    init(delegate: DateOfBirthDelegate, dateOfBirth: Date) {
        self.gender = delegate.gender
        self.dateOfBirth = dateOfBirth
    }
    
    static var mock: Self {
        Self(delegate: .mock, dateOfBirth: Date.now.addingTimeInterval(days: (-365*25)))
    }
}

/// Every onboarding wheel (height, weight, target weight) takes the full row width at its natural
/// height; two wheels side by side split the row evenly.
struct HeightView: View {

    @State var presenter: HeightPresenter

    var delegate: HeightDelegate

    var body: some View {
        OnboardingStepScaffold(
            title: "How Tall Are You?",
            progress: OnboardingStep.completeAccountSetup.progress,
            primary: .init(title: "Continue", identifier: "Continue") { presenter.onContinuePressed(delegate: delegate) },
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            pickerSection
            if presenter.unit == .centimeters {
                metricSection
            } else {
                imperialSection
            }
        }
    }

    private var pickerSection: some View {
        Section {
            Picker("Units", selection: $presenter.unit) {
                Text("Metric").tag(UnitOfLength.centimeters)
                Text("Imperial").tag(UnitOfLength.inches)
            }
            .pickerStyle(.segmented)
        }
        .removeListRowFormatting()
    }

    private var metricSection: some View {
        Section {
            Picker("Centimeters", selection: $presenter.selectedCentimeters) {
                ForEach((100...250).reversed(), id: \.self) { value in
                    Text("\(value) cm").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .onChange(of: presenter.selectedCentimeters) { _, _ in
                presenter.updateImperialFromCentimeters()
            }
        } header: {
            Text("Metric")
        }
        .removeListRowFormatting()
    }

    private var imperialSection: some View {
        Section {
            HStack(spacing: Spacing.m) {
                Picker("Feet", selection: $presenter.selectedFeet) {
                    ForEach((3...8).reversed(), id: \.self) { feet in
                        Text("\(feet) ft").tag(feet)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: presenter.selectedFeet) { _, _ in
                    presenter.updateCentimetersFromImperial()
                }

                Picker("Inches", selection: $presenter.selectedInches) {
                    ForEach((0...11).reversed(), id: \.self) { inch in
                        Text("\(inch) in").tag(inch)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: presenter.selectedInches) { _, _ in
                    presenter.updateCentimetersFromImperial()
                }
            }
        } header: {
            Text("Imperial")
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
    func heightView(router: AnyRouter, delegate: HeightDelegate) -> some View {
        HeightView(
            presenter: HeightPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showHeightView(delegate: HeightDelegate) {
        router.showScreen(.push) { router in
            builder.heightView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.heightView(
            router: router,
            delegate: .mock
        )
    }
    
}
