import SwiftUI

struct AddGymMachineDelegate {
    var onAdd: (GymMachineDraft) -> Void
}

struct AddGymMachineView: View {

    @State var presenter: AddGymMachinePresenter

    var body: some View {
        Form {
            Section {
                Picker("Kind", selection: $presenter.kind) {
                    ForEach(AddGymMachinePresenter.kinds) { kind in
                        Text(kind.machineKindTitle).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                TextField(String(localized: "Name"), text: $presenter.name)
                    .font(.rowTitle)
            }
            Section {
                Picker("Works as", selection: $presenter.worksAs) {
                    Text("None").tag(String?.none)
                    ForEach(presenter.catalogueMachines) { machine in
                        Text(machine.name).tag(Optional(machine.ref.equipmentId))
                    }
                }
                .pickerStyle(.navigationLink)
            } footer: {
                Text("Exercises for the chosen machine use this one too. With None, it is a machine of its own that you can pick when creating an exercise.")
            }
        }
        .navigationTitle("Add Machine")
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
            .disabled(!presenter.canSave)
        }
    }
}

extension CoreBuilder {

    func addGymMachineView(router: AnyRouter, delegate: AddGymMachineDelegate) -> some View {
        AddGymMachineView(
            presenter: AddGymMachinePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }
}

extension CoreRouter {

    /// The new machine is handed over once the sheet is down, so the editor it opens is pushed
    /// on the gym screen rather than lost under a closing sheet.
    func showAddGymMachineView(delegate: AddGymMachineDelegate) {
        var added: GymMachineDraft?
        router.showScreen(
            .sheetConfig(config: .half),
            onDidDismiss: {
                if let added { delegate.onAdd(added) }
            },
            destination: { router in
                builder.addGymMachineView(router: router, delegate: AddGymMachineDelegate { added = $0 })
            }
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    return RouterView { router in
        builder.addGymMachineView(router: router, delegate: AddGymMachineDelegate { _ in })
    }
}
