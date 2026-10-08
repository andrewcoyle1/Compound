import SwiftUI

struct EditPlateLoadedMachineView: View {
    
    @State var presenter: EditPlateLoadedMachinePresenter
    
    var body: some View {
        List {
            pickerSection
        }
        .navigationTitle(presenter.plateLoadedMachine.name)
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
                    TextField("", value: $presenter.plateLoadedMachine.baseWeight, format: .number)
                        .textFieldStyle(.roundedBorder)
                    Spacer()
                    Picker("Unit", selection: $presenter.plateLoadedMachine.unit) {
                        ForEach(ExerciseWeightUnit.allCases, id: \.self) { unit in
                            Text(unit.abbreviation)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }
            VStack(alignment: .leading) {
                Text("Plates go on")
                    .font(.sectionTitle)
                // One side: a T-bar row or belt squat takes its plates on a single post, so the
                // smallest change is one plate rather than a pair.
                Picker("Plates go on", selection: $presenter.plateLoadedMachine.sleeves) {
                    Text("One side").tag(1)
                    Text("Two sides").tag(2)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
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
    
    func editPlateLoadedMachineView(router: AnyRouter, plateLoadedMachine: Binding<PlateLoadedMachine>) -> some View {
        EditPlateLoadedMachineView(
            presenter: EditPlateLoadedMachinePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                plateLoadedMachineBinding: plateLoadedMachine
            )
        )
    }
}

extension CoreRouter {
    
    func showEditPlateLoadedMachineView(plateLoadedMachine: Binding<PlateLoadedMachine>) {
        router.showScreen(.sheetConfig(config: .compact)) { router in
            builder.editPlateLoadedMachineView(router: router, plateLoadedMachine: plateLoadedMachine)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let plateLoadedMachine = PlateLoadedMachine.mock
    return RouterView { router in
        builder.editPlateLoadedMachineView(router: router, plateLoadedMachine: Binding.constant(plateLoadedMachine))
    }
    
}
