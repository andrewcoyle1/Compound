import SwiftUI

struct EditDeloadView: View {

    @State var presenter: EditDeloadPresenter

    var body: some View {
        List {
            ForEach(presenter.allCases, id: \.self) { type in
                SelectableRow(title: type.title, subtitle: type.description, isSelected: type == presenter.selected) {
                    presenter.onSelect(type)
                }
            }
        }
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
        .navigationTitle("Deload")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) { presenter.onCancelPressed() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) { presenter.onSavePressed() }
            }
        }
    }
}

extension CoreBuilder {
    func editDeloadView(router: AnyRouter, selected: DeloadType, onSave: @escaping (DeloadType) -> Void) -> some View {
        let coreRouter = CoreRouter(router: router, builder: self)
        return EditDeloadView(
            presenter: EditDeloadPresenter(
                selected: selected,
                onSave: onSave,
                interactor: interactor,
                router: coreRouter
            )
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    RouterView { router in
        builder.editDeloadView(
            router: router,
            selected: .none,
            onSave: { _ in }
        )
    }
}
