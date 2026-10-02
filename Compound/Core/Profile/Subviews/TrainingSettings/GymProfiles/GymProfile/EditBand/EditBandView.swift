import SwiftUI

struct EditBandView: View {
    
    @State var presenter: EditBandPresenter
    
    var body: some View {
        @Bindable var presenter = presenter
        List {
            weightsList
        }
        .navigationTitle(presenter.band.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .scrollIndicators(.hidden)
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
                        Circle()
                            .frame(maxHeight: 20)
                            .foregroundStyle(Color(hex: weight.wrappedValue.bandColour))
                        VStack(alignment: .leading) {
                            Text(weight.wrappedValue.name)
                                .fontWeight(.semibold)
                            Text("Up to \(GymEquipmentFormat.weight(weight.wrappedValue.availableResistance, weight.wrappedValue.unit))")
                                .font(.rowDetail)
                        }
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
            .accessibilityLabel("Add band")
        }
    }
}

extension CoreBuilder {
    
    func editBandView(router: AnyRouter, band: Binding<Bands>) -> some View {
        EditBandView(
            presenter: EditBandPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                bandBinding: band
            )
        )
    }
}

extension CoreRouter {
    
    func showEditBandView(band: Binding<Bands>) {
        // Pushed inside the Profile sheet: browsing a list is a push, and only the Add form above it
        // is a sheet, so at most one modal sits over Profile.
        router.showScreen(.push) { router in
            builder.editBandView(router: router, band: band)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let band = Bands.mock
    return RouterView { router in
        builder.editBandView(router: router, band: Binding.constant(band))
    }
    
}
