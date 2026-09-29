import SwiftUI

struct EditLoadableAccessoryView: View {
    
    @State var presenter: EditLoadableAccessoryPresenter
    
    var body: some View {
        List {
            pickerSection
        }
        .navigationTitle(presenter.loadableAccessory.name)
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
    
    private var pickerSection: some View {
        Section {
            VStack(alignment: .leading) {
                Text("Weights")
                    .font(.sectionTitle)
                HStack {
                    TextField("", value: $presenter.loadableAccessory.baseWeight, format: .number)
                        .textFieldStyle(.roundedBorder)
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
        .listSectionMargins(.vertical, 0)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }
    }
}

extension CoreBuilder {
    
    func editLoadableAccessoryView(router: AnyRouter, loadableAccessory: Binding<LoadableAccessoryEquipment>) -> some View {
        EditLoadableAccessoryView(
            presenter: EditLoadableAccessoryPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                loadableAccessoryBinding: loadableAccessory
            )
        )
    }
}

extension CoreRouter {
    
    func showEditLoadableAccessoryView(loadableAccessory: Binding<LoadableAccessoryEquipment>) {
        router.showScreen(.sheetConfig(config: .compact)) { router in
            builder.editLoadableAccessoryView(router: router, loadableAccessory: loadableAccessory)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let loadableAccessory = LoadableAccessoryEquipment.mock
    return RouterView { router in
        builder.editLoadableAccessoryView(router: router, loadableAccessory: Binding.constant(loadableAccessory))
    }
    
}
