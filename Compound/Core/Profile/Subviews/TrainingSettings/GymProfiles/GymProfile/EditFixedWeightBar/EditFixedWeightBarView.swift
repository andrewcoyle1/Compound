import SwiftUI

struct EditFixedWeightBarView: View {
    
    @State var presenter: EditFixedWeightBarPresenter
    
    var body: some View {
        @Bindable var presenter = presenter
        List {
            weightsList
        }
        .navigationTitle(presenter.fixedWeightBar.name)
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
                .sorted { presenter.weightValue(for: $0) < presenter.weightValue(for: $1) }
            if weightIDs.isEmpty {
                ContentUnavailableView(
                    "No \(presenter.selectedUnit.displayName) weights",
                    systemImage: Symbol.equipment,
                    description: Text("There are no weights for the selected unit.")
                )
            } else {
                ForEach(weightIDs, id: \.self) { weightID in
                    let weight = presenter.bindingForWeight(id: weightID, fallbackUnit: unit)
                    HStack {
                        Text(GymEquipmentFormat.weight(weight.wrappedValue.baseWeight, weight.wrappedValue.unit))
                        Spacer()
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
            .accessibilityLabel("Add fixed-weight bar")
        }

    }
}

extension CoreBuilder {
    
    func editFixedWeightBarView(router: AnyRouter, fixedWeightBar: Binding<FixedWeightBars>) -> some View {
        EditFixedWeightBarView(
            presenter: EditFixedWeightBarPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                fixedWeightBarBinding: fixedWeightBar
            )
        )
    }
}

extension CoreRouter {
    
    func showEditFixedWeightBarView(fixedWeightBar: Binding<FixedWeightBars>) {
        // Pushed inside the Profile sheet: browsing a list is a push, and only the Add form above it
        // is a sheet, so at most one modal sits over Profile.
        router.showScreen(.push) { router in
            builder.editFixedWeightBarView(router: router, fixedWeightBar: fixedWeightBar)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let fixedWeightBar = FixedWeightBars.mock
    return RouterView { router in
        builder.editFixedWeightBarView(router: router, fixedWeightBar: Binding.constant(fixedWeightBar))
    }
    
}
