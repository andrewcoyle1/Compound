import SwiftUI

struct EditProgramColourIconView: View {

    @State var presenter: EditProgramColourIconPresenter

    var body: some View {
        VStack {
            ProgramColourIconGrid(
                colours: presenter.colours,
                icons: presenter.icons,
                selectedColour: presenter.selectedColour,
                selectedIcon: presenter.selectedIcon,
                onColourPressed: { presenter.onColourPressed($0) },
                onIconPressed: { presenter.onIconPressed($0) }
            )
            Spacer()
        }
        .padding(.top)
        .background(Color.canvas)
        .navigationTitle("Colour & Icon")
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
    func editProgramColourIconView(router: AnyRouter, colour: String, icon: String, onSave: @escaping (String, String) -> Void) -> some View {
        let coreRouter = CoreRouter(router: router, builder: self)
        return EditProgramColourIconView(
            presenter: EditProgramColourIconPresenter(
                colour: colour,
                icon: icon,
                onSave: onSave,
                router: coreRouter
            )
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    RouterView { router in
        builder.editProgramColourIconView(
            router: router,
            colour: Color.blue.asHex(),
            icon: "flag.pattern.checkered",
            onSave: { _, _ in }
        )
    }
}
