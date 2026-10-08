import SwiftUI

struct AddFreeWeightDelegate {
    var freeWeight: Binding<FreeWeights>
    var unit: ExerciseWeightUnit
}

struct AddFreeWeightView: View {
    
    @State var presenter: AddFreeWeightPresenter
    
    var body: some View {
        Form {
            Section {
                if presenter.freeWeight.wrappedValue.needsColour {
                    colourSection
                }
                weightSection
                if presenter.freeWeight.wrappedValue.isPlates {
                    countSection
                }
            }
            .listSectionMargins(.vertical, 0)
            if let message = presenter.validationMessage {
                Section {
                    InlineMessage(.info, message)
                }
            }
        }
        .navigationTitle("Add")
        .navigationSubtitle(presenter.freeWeight.wrappedValue.name)
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
    
    private var colourSection: some View {
        EquipmentColourPicker(
            title: "Plate Color",
            colours: presenter.colours,
            selectedColour: presenter.selectedColour
        ) { colour in
            presenter.onColourPressed(colour: colour)
        }
    }

    private var weightSection: some View {
        VStack(alignment: .leading) {
            Text("Weight")
                .font(.sectionTitle)
            ZStack(alignment: .trailing) {
                TextField("Weight", value: $presenter.freeWeightAvailable.availableWeights, format: .number, prompt: Text("0"))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                Text(presenter.unit.abbreviation)
                    .padding(.trailing)
            }
        }
    }
    
    /// Empty is no limit, which is what every plate meant before counts existed.
    private var countSection: some View {
        VStack(alignment: .leading) {
            Text("How many")
                .font(.sectionTitle)
            TextField("How many", value: $presenter.freeWeightAvailable.count, format: .number, prompt: Text("No limit"))
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }
        
        ToolbarItem(placement: .confirmationAction) {
            Button(role: .confirm) {
                presenter.onSavePressed()
            }
            .disabled(presenter.validationMessage != nil)
        }
    }
}

extension CoreBuilder {
    
    func addFreeWeightView(router: AnyRouter, delegate: AddFreeWeightDelegate) -> some View {
        AddFreeWeightView(
            presenter: AddFreeWeightPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }

}

extension CoreRouter {
    
    func showAddFreeWeightView(delegate: AddFreeWeightDelegate) {
        router.showScreen(.sheetConfig(config: .compact)) { router in
            builder.addFreeWeightView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    @Previewable @State var freeWeight: FreeWeights = FreeWeights.mock
    let unit: ExerciseWeightUnit = .kilograms
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = AddFreeWeightDelegate(freeWeight: $freeWeight, unit: unit)
    
    return RouterView { router in
        builder.addFreeWeightView(router: router, delegate: delegate)
    }
    
}
