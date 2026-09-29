import SwiftUI

struct EditLoadableBarView: View {
    
    @State var presenter: EditLoadableBarPresenter
    
    var body: some View {
        @Bindable var presenter = presenter
        List {
            weightsList
        }
        .navigationTitle(presenter.loadableBar.name)
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
            .accessibilityLabel("Add loadable bar")
        }
    }
}

extension CoreBuilder {
    
    func editLoadableBarView(router: AnyRouter, loadableBar: Binding<LoadableBars>) -> some View {
        EditLoadableBarView(
            presenter: EditLoadableBarPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                loadableBarBinding: loadableBar
            )
        )
    }
}

extension CoreRouter {
    
    func showEditLoadableBarView(loadableBar: Binding<LoadableBars>) {
        router.showScreen(.sheet) { router in
            builder.editLoadableBarView(router: router, loadableBar: loadableBar)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let loadableBar = LoadableBars.mock
    return RouterView { router in
        builder.editLoadableBarView(router: router, loadableBar: Binding.constant(loadableBar))
    }
    
}
