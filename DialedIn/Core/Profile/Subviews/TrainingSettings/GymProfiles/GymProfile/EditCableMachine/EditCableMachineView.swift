import SwiftUI

struct EditCableMachineView: View {
    
    @State var presenter: EditCableMachinePresenter
    
    var body: some View {
        List {
            weightsList
        }
        .navigationTitle(presenter.cableMachine.name)
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
            .accessibilityLabel("Add cable machine")
        }
    }
}

extension CoreBuilder {
    
    func editCableMachineView(router: AnyRouter, cableMachine: Binding<CableMachine>) -> some View {
        EditCableMachineView(
            presenter: EditCableMachinePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                cableMachineBinding: cableMachine
            )
        )
    }
}

extension CoreRouter {
    
    func showEditCableMachineView(cableMachine: Binding<CableMachine>) {
        router.showScreen(.sheet) { router in
            builder.editCableMachineView(router: router, cableMachine: cableMachine)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let cableMachine = CableMachine.mock
    return RouterView { router in
        builder.editCableMachineView(router: router, cableMachine: Binding.constant(cableMachine))
    }
    
}
