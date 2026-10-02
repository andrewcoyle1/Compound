import SwiftUI

struct AddLoadableBarDelegate {
    var loadableBar: Binding<LoadableBars>
    var unit: ExerciseWeightUnit
}

struct AddLoadableBarView: View {
    
    @State var presenter: AddLoadableBarPresenter
    
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
        .navigationSubtitle(presenter.loadableBar.wrappedValue.name)
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
                TextField("Weight", value: $presenter.loadableBarBaseWeight.baseWeight, format: .number, prompt: Text("0"))
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
    
    func addLoadableBarView(router: AnyRouter, delegate: AddLoadableBarDelegate) -> some View {
        AddLoadableBarView(
            presenter: AddLoadableBarPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }

}

extension CoreRouter {
    
    func showAddLoadableBarView(delegate: AddLoadableBarDelegate) {
        router.showScreen(.sheetConfig(config: .compact)) { router in
            builder.addLoadableBarView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    @Previewable @State var loadableBar: LoadableBars = LoadableBars.mock
    let unit: ExerciseWeightUnit = .kilograms
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = AddLoadableBarDelegate(loadableBar: $loadableBar, unit: unit)
    
    return RouterView { router in
        builder.addLoadableBarView(router: router, delegate: delegate)
    }
    
}
