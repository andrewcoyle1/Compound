import SwiftUI

struct AddBodyWeightDelegate {
    var bodyWeight: Binding<BodyWeights>
    var unit: ExerciseWeightUnit
}

struct AddBodyWeightView: View {
    
    @State var presenter: AddBodyWeightPresenter
    
    var body: some View {
        Form {
            Section {
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
        .navigationSubtitle(presenter.bodyWeight.wrappedValue.name)
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
        
    private var weightSection: some View {
        VStack(alignment: .leading) {
            Text("Weight")
                .font(.sectionTitle)
            ZStack(alignment: .trailing) {
                TextField("Weight", value: $presenter.bodyWeightAvailable.availableWeights, format: .number, prompt: Text("0"))
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
    
    func addBodyWeightView(router: AnyRouter, delegate: AddBodyWeightDelegate) -> some View {
        AddBodyWeightView(
            presenter: AddBodyWeightPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }

}

extension CoreRouter {
    
    func showAddBodyWeightView(delegate: AddBodyWeightDelegate) {
        router.showScreen(.sheetConfig(config: .compact)) { router in
            builder.addBodyWeightView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    @Previewable @State var bodyWeight: BodyWeights = BodyWeights.mock
    let unit: ExerciseWeightUnit = .kilograms
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = AddBodyWeightDelegate(bodyWeight: $bodyWeight, unit: unit)
    
    return RouterView { router in
        builder.addBodyWeightView(router: router, delegate: delegate)
    }
    
}
