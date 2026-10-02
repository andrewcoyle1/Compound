import SwiftUI

struct AddBandDelegate {
    var band: Binding<Bands>
    var unit: ExerciseWeightUnit
}

struct AddBandView: View {
    
    @State var presenter: AddBandPresenter
    
    var body: some View {
        Form {
            Section {
                colourSection
                labelSection
                weightSection
            }
            .listSectionMargins(.vertical, 0)
            if let message = presenter.validationMessage {
                Section {
                    InlineMessage(.info, message)
                }
            }
        }
        .navigationTitle("Add")
        .navigationSubtitle(presenter.band.wrappedValue.name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
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
            title: "Band Color",
            colours: presenter.colours,
            selectedColour: presenter.selectedColour
        ) { colour in
            presenter.onColourPressed(colour: colour)
        }
    }

    private var labelSection: some View {
        VStack(alignment: .leading) {
            Text("Label")
                .font(.sectionTitle)
            ZStack(alignment: .trailing) {
                TextField(text: $presenter.bandAvailable.name, label: { Text("Label") })
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.default)
            }
        }
    }

    private var weightSection: some View {
        VStack(alignment: .leading) {
            Text("Weight")
                .font(.sectionTitle)
            ZStack(alignment: .trailing) {
                TextField("Weight", value: $presenter.bandAvailable.availableResistance, format: .number, prompt: Text("0"))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                Text(presenter.unit.abbreviation)
                    .padding(.trailing)
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
        
        ToolbarItem(placement: .confirmationAction) {
            Button(role: .confirm) {
                presenter.onSavePressed()
            }
            .disabled(presenter.validationMessage != nil)
        }
    }
}

extension CoreBuilder {
    
    func addBandView(router: AnyRouter, delegate: AddBandDelegate) -> some View {
        AddBandView(
            presenter: AddBandPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }

}

extension CoreRouter {
    
    func showAddBandView(delegate: AddBandDelegate) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.addBandView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    @Previewable @State var band: Bands = Bands.mock
    let unit: ExerciseWeightUnit = .kilograms
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = AddBandDelegate(band: $band, unit: unit)
    
    return RouterView { router in
        builder.addBandView(router: router, delegate: delegate)
    }
    
}
