import SwiftUI

struct EditPinLoadedMachineView: View {
    
    @State var presenter: EditPinLoadedMachinePresenter
    
    var body: some View {
        @Bindable var presenter = presenter
        List {
            weightsList
        }
        .navigationTitle(presenter.pinLoadedMachine.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .toolbar {
            toolbarContent
        }
    }
        
    private var weightsList: some View {
        Section {
            let unit = presenter.selectedUnit
            let weightIDs = presenter.filteredWeightIDs(for: unit)
            if weightIDs.isEmpty {
                ContentUnavailableView(
                    "No \(presenter.selectedUnit.displayName) weights",
                    systemImage: Symbol.equipment,
                    description: Text("There are no weights for the selected unit.")
                )
            } else {
                ForEach(weightIDs, id: \.self) { weightID in
                    let weight = presenter.bindingForWeight(id: weightID, fallbackUnit: unit)
                    HStack(spacing: Spacing.m) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(weight.wrappedValue.name)
                                .font(.rowTitle)
                            Text(GymEquipmentFormat.range(min: weight.wrappedValue.minWeight, max: weight.wrappedValue.maxWeight, increment: weight.wrappedValue.increment, unit: weight.wrappedValue.unit))
                                .font(.rowDetail)
                                .foregroundStyle(.secondary)
                            Button("Edit Range") {
                                presenter.onEditRangePressed(range: weight)
                            }
                            .font(.rowDetail.weight(.semibold))
                            .foregroundStyle(.tint)
                            .buttonStyle(.borderless)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Toggle("Available", isOn: weight.isActive)
                            .labelsHidden()
                    }
                }
                .onDelete { offsets in
                    presenter.deleteWeights(at: offsets, weightIDs: weightIDs)
                }
            }
        } header: {
            HStack {
                Text("Weights")
                Spacer()
                Picker("Unit", selection: $presenter.selectedUnit) {
                    ForEach(ExerciseWeightUnit.allCases, id: \.self) { unit in
                        Text(unit.abbreviation)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onAddPressed()
            } label: {
                Image(systemName: Symbol.add)
            }
            .accessibilityLabel("Add pin-loaded machine")
        }
    }
}

extension CoreBuilder {
    
    func editPinLoadedMachineView(router: AnyRouter, pinLoadedMachine: Binding<PinLoadedMachine>) -> some View {
        EditPinLoadedMachineView(
            presenter: EditPinLoadedMachinePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                pinLoadedMachineBinding: pinLoadedMachine
            )
        )
    }
}

extension CoreRouter {
    
    func showEditPinLoadedMachineView(pinLoadedMachine: Binding<PinLoadedMachine>) {
        router.showScreen(.sheet) { router in
            builder.editPinLoadedMachineView(router: router, pinLoadedMachine: pinLoadedMachine)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let pinLoadedMachine = PinLoadedMachine.mock
    return RouterView { router in
        builder.editPinLoadedMachineView(router: router, pinLoadedMachine: Binding.constant(pinLoadedMachine))
    }
    
}
