import SwiftUI

struct RenameWorkoutTemplateModelDelegate {
    let initialName: String
    let onSave: (String) -> Void
}

struct RenameWorkoutTemplateModelView: View {
    @State var presenter: RenameWorkoutTemplateModelPresenter
    let delegate: RenameWorkoutTemplateModelDelegate

    var body: some View {
        Form {
            Section("Name") {
                TextField("Day name", text: $presenter.nameText)
            }
        }
        .navigationTitle("Rename Day")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onCancelPressed()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(role: .confirm) {
                presenter.onSavePressed(onSave: delegate.onSave)
            }
            .disabled(!presenter.canSave)
        }
    }
}

extension CoreBuilder {
    func renameWorkoutTemplateModelView(router: AnyRouter, delegate: RenameWorkoutTemplateModelDelegate) -> some View {
        RenameWorkoutTemplateModelView(
            presenter: RenameWorkoutTemplateModelPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                initialName: delegate.initialName
            ),
            delegate: delegate
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.renameWorkoutTemplateModelView(
            router: router,
            delegate: RenameWorkoutTemplateModelDelegate(
                initialName: "Day 1",
                onSave: { _ in }
            )
        )
    }
    
}
