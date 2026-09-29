import SwiftUI

struct AddCableMachineRangeDelegate {
    var cableMachine: Binding<CableMachine>
    var unit: ExerciseWeightUnit
}

struct AddCableMachineRangeView: View {
    
    @State var presenter: AddCableMachineRangePresenter
    
    var body: some View {
        List {
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
        .navigationSubtitle(presenter.cableMachine.wrappedValue.name)
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
    
    func addCableMachineRangeView(router: AnyRouter, delegate: AddCableMachineRangeDelegate) -> some View {
        AddCableMachineRangeView(
            presenter: AddCableMachineRangePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }
    
}

extension CoreRouter {
    
    func showAddCableMachineRangeView(delegate: AddCableMachineRangeDelegate) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.addCableMachineRangeView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    @Previewable @State var cableMachine: CableMachine = CableMachine.mock
    let unit: ExerciseWeightUnit = .kilograms
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = AddCableMachineRangeDelegate(cableMachine: $cableMachine, unit: unit)
    
    return RouterView { router in
        builder.addCableMachineRangeView(router: router, delegate: delegate)
    }
    
}
