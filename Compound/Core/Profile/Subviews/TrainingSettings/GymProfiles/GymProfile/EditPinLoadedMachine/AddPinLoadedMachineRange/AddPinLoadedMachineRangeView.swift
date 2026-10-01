import SwiftUI

struct AddPinLoadedMachineRangeDelegate {
    var pinLoadedMachine: Binding<PinLoadedMachine>
    var unit: ExerciseWeightUnit
}

struct AddPinLoadedMachineRangeView: View {
    
    @State var presenter: AddPinLoadedMachineRangePresenter
    
    var body: some View {
        Form {
            Section {
                nameSection
                rangeStartSection
                rangeEndSection
                incrementSection
            }
            .listSectionMargins(.vertical, 0)
            if let message = presenter.validationMessage {
                Section {
                    InlineMessage(.info, message)
                }
            }
        }
        .navigationTitle("Add Range")
        .navigationSubtitle(presenter.pinLoadedMachine.wrappedValue.name)
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
    
    private var nameSection: some View {
        VStack(alignment: .leading) {
            Text("Label")
                .font(.sectionTitle)
                .padding(.top, Spacing.xs)
            TextField(text: $presenter.range.name, label: { Text("Label") })
                .textFieldStyle(.roundedBorder)
        }
    }

    private var rangeStartSection: some View {
        VStack(alignment: .leading) {
            Text("Range Start")
                .font(.sectionTitle)
                .padding(.top, Spacing.xs)
            ZStack(alignment: .trailing) {
                TextField("Range Start", value: $presenter.range.minWeight, format: .number, prompt: Text("0"))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                Text(presenter.unit.abbreviation)
                    .padding(.trailing)
            }
        }
    }
    
    private var rangeEndSection: some View {
        VStack(alignment: .leading) {
            Text("Range End")
                .font(.sectionTitle)
            ZStack(alignment: .trailing) {
                TextField("Range End", value: $presenter.range.maxWeight, format: .number, prompt: Text("0"))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                Text(presenter.unit.abbreviation)
                    .padding(.trailing)
            }
        }
    }
    
    private var incrementSection: some View {
        VStack(alignment: .leading) {
            Text("Increment")
                .font(.sectionTitle)
            ZStack(alignment: .trailing) {
                TextField("Increment", value: $presenter.range.increment, format: .number, prompt: Text("0"))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                Text(presenter.unit.abbreviation)
                    .padding(.trailing)
            }
            .padding(.bottom, Spacing.xs)
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
    
    func addPinLoadedMachineRangeView(router: AnyRouter, delegate: AddPinLoadedMachineRangeDelegate) -> some View {
        AddPinLoadedMachineRangeView(
            presenter: AddPinLoadedMachineRangePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }
    
}

extension CoreRouter {
    
    func showAddPinLoadedMachineRangeView(delegate: AddPinLoadedMachineRangeDelegate) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.addPinLoadedMachineRangeView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    @Previewable @State var pinLoadedMachine: PinLoadedMachine = PinLoadedMachine.mock
    let unit: ExerciseWeightUnit = .kilograms
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = AddPinLoadedMachineRangeDelegate(pinLoadedMachine: $pinLoadedMachine, unit: unit)
    
    return RouterView { router in
        builder.addPinLoadedMachineRangeView(router: router, delegate: delegate)
    }
    
}
