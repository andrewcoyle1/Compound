import SwiftUI

struct EditBodyWeightView: View {
    
    @State var presenter: EditBodyWeightPresenter
    
    var body: some View {
        @Bindable var presenter = presenter
        List {
            weightsList
        }
        .navigationTitle(presenter.bodyWeight.name)
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
                        if let colour = weight.wrappedValue.plateColour {
                            Circle()
                                .frame(maxHeight: 20)
                                .foregroundStyle(Color(hex: colour))
                        }
                        Text(GymEquipmentFormat.weight(weight.wrappedValue.availableWeights, weight.wrappedValue.unit))
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
            .accessibilityLabel("Add body weight")
        }
    }
}

extension CoreBuilder {
    
    func editBodyWeightView(router: AnyRouter, bodyWeight: Binding<BodyWeights>) -> some View {
        EditBodyWeightView(
            presenter: EditBodyWeightPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                bodyWeight: bodyWeight
            )
        )
    }
    
}

extension CoreRouter {
    
    func showEditBodyWeightView(bodyWeight: Binding<BodyWeights>) {
        // Pushed inside the Profile sheet: browsing a list is a push, and only the Add form above it
        // is a sheet, so at most one modal sits over Profile.
        router.showScreen(.push) { router in
            builder.editBodyWeightView(router: router, bodyWeight: bodyWeight)
        }
    }
    
}

#Preview {
    @Previewable @State var bodyWeight: BodyWeights = BodyWeights.mock
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    
    return RouterView { router in
        builder.editBodyWeightView(router: router, bodyWeight: $bodyWeight)
    }
    
}
