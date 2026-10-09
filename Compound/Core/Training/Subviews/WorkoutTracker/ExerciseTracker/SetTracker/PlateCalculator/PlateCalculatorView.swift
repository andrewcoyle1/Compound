//
//  PlateCalculatorView.swift
//  Compound
//
//  Opened from the loading bar above the weight keyboard: the set's weight on the bar, the bar
//  the gym loads, and the plates it has. Done saves both to the gym; Close discards them.
//

import SwiftUI

struct PlateCalculatorView: View {

    @State var presenter: PlateCalculatorPresenter
    @ScaledMetric(relativeTo: .body) private var plateChipWidth: CGFloat = 64

    var body: some View {
        List {
            Section {
                if let loading = presenter.loading {
                    PlateLoadingView(loading: loading, plates: presenter.step.plates)
                } else if let text = presenter.notLoadableText {
                    Label(text, systemImage: Symbol.warning)
                        .foregroundStyle(.danger)
                }
            }

            barSection

            Section("Available Plate Weights") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: plateChipWidth), spacing: Spacing.s)], spacing: Spacing.s) {
                    ForEach(presenter.plateChoices) { choice in
                        Button {
                            presenter.onPlateToggled(choice)
                        } label: {
                            Chip("\(WeightStepper.format(choice.weight)) \(presenter.unit.abbreviation)", isSelected: choice.isOn)
                                .monospacedDigit()
                                .chipTapTarget()
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(choice.isOn ? .isSelected : [])
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
        }
        .navigationTitle("Plate Calculator")
        .navigationSubtitle(presenter.subtitle ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Done saves the bar and plates to the gym; Close leaves the gym as it was.
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onClosePressed()
                }
            }
        }
        .bottomCTA {
            CallToActionButton {
                presenter.onDonePressed()
            } label: {
                Text("Done")
            }
        }
        .onAppear { presenter.onViewAppear() }
    }

    @ViewBuilder
    private var barSection: some View {
        let choices = presenter.barChoices
        if choices.count > 1 {
            Section {
                Picker("Bar Weight", selection: Binding(
                    get: { presenter.chosenBarId ?? "" },
                    set: { presenter.onBarChosen($0) }
                )) {
                    ForEach(choices) { choice in
                        Text(choice.title).tag(choice.id)
                    }
                }
                .pickerStyle(.menu)
            } footer: {
                Text("Used for every exercise on this bar at this gym.")
            }
        } else if let base = presenter.step.baseWeight {
            Section {
                LabeledContent(
                    presenter.barChoices.isEmpty ? String(localized: "Base") : String(localized: "Bar Weight"),
                    value: "\(WeightStepper.format(base)) \(presenter.unit.abbreviation)"
                )
            }
        }
    }
}

extension CoreBuilder {
    func plateCalculatorView(router: AnyRouter, delegate: PlateCalculatorDelegate) -> some View {
        PlateCalculatorView(
            presenter: PlateCalculatorPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }
}

extension CoreRouter {
    func showPlateCalculatorView(delegate: PlateCalculatorDelegate) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.plateCalculatorView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    return RouterView { router in
        builder.plateCalculatorView(
            router: router,
            delegate: PlateCalculatorDelegate(
                gym: .mock,
                equipment: EquipmentRef(kind: .loadableBar, id: "barbell"),
                unit: .kilograms,
                total: 70,
                onSave: { _ in }
            )
        )
    }
}
