import SwiftUI

struct EditStackMachineView<Machine: StackMachine>: View {

    @State var presenter: EditStackMachinePresenter<Machine>

    var body: some View {
        List {
            if presenter.isCustom {
                Section("Name") {
                    TextField(String(localized: "Name"), text: $presenter.machine.name)
                        .font(.rowTitle)
                }
            }
            weightsList
        }
        .navigationTitle(presenter.machine.name)
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
                            Text(GymEquipmentFormat.stack(weight.wrappedValue))
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
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onAddPressed()
            } label: {
                Image(systemName: Symbol.add)
            }
            .accessibilityLabel("Add Range")
        }
    }
}

extension CoreBuilder {

    func editStackMachineView<Machine: StackMachine>(router: AnyRouter, machine: Binding<Machine>) -> some View {
        EditStackMachineView(
            presenter: EditStackMachinePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                machineBinding: machine
            )
        )
    }
}

extension CoreRouter {

    func showEditStackMachineView<Machine: StackMachine>(machine: Binding<Machine>) {
        // Pushed inside the Profile sheet: browsing a list is a push, and only the Add form above it
        // is a sheet, so at most one modal sits over Profile.
        router.showScreen(.push) { router in
            builder.editStackMachineView(router: router, machine: machine)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    return RouterView { router in
        builder.editStackMachineView(router: router, machine: Binding.constant(CableMachine.mock))
    }
}
