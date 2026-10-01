import SwiftUI

struct AddFixedWeightBarDelegate {
    var fixedWeightBar: Binding<FixedWeightBars>
    var unit: ExerciseWeightUnit
}

struct AddFixedWeightBarView: View {
    
    @State var presenter: AddFixedWeightBarPresenter
    
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
        .navigationSubtitle(presenter.fixedWeightBar.wrappedValue.name)
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
                TextField("Weight", value: $presenter.fixedWeightBarBaseWeight.baseWeight, format: .number, prompt: Text("0"))
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
    
    func addFixedWeightBarView(router: AnyRouter, delegate: AddFixedWeightBarDelegate) -> some View {
        AddFixedWeightBarView(
            presenter: AddFixedWeightBarPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }

}

extension CoreRouter {
    
    func showAddFixedWeightBarView(delegate: AddFixedWeightBarDelegate) {
        router.showScreen(.sheetConfig(config: .compact)) { router in
            builder.addFixedWeightBarView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    @Previewable @State var fixedWeightBar: FixedWeightBars = FixedWeightBars.mock
    let unit: ExerciseWeightUnit = .kilograms
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = AddFixedWeightBarDelegate(fixedWeightBar: $fixedWeightBar, unit: unit)
    
    return RouterView { router in
        builder.addFixedWeightBarView(router: router, delegate: delegate)
    }
    
}
