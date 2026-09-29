import SwiftUI

struct EditUsernameView: View {

    @State var presenter: EditUsernamePresenter

    var body: some View {
        List {
            Section {
                HStack(spacing: 2) {
                    Text(verbatim: "@")
                        .foregroundStyle(.secondary)
                    TextField("username", text: $presenter.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .accessibilityIdentifier("UsernameField")
                }
            } footer: {
                statusLabel
            }
        }
        .navigationTitle("Username")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if presenter.isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task { await presenter.onSavePressed() }
                    }
                    .disabled(!presenter.canSave)
                }
            }
        }
        .onChange(of: presenter.text) {
            presenter.onTextChanged()
        }
        .onAppear {
            presenter.onViewAppear()
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch presenter.status {
        case .idle:
            Text("3–20 characters: letters, numbers, underscores and dots. Friends can find you by it.")
        case .current:
            Text("This is your username.")
        case .invalid(let message):
            Label(message, systemImage: "exclamationmark.circle")
                .foregroundStyle(.orange)
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Checking…")
            }
        case .available:
            Label("Available", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .taken:
            Label("Taken", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .failed:
            Text("Couldn't check that username. Try again in a moment.")
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)

    RouterView { router in
        builder.editUsernameView(router: router)
    }
}

extension CoreBuilder {

    func editUsernameView(router: AnyRouter) -> some View {
        EditUsernameView(
            presenter: EditUsernamePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
}

extension CoreRouter {

    func showEditUsernameView() {
        router.showScreen(.push) { router in
            builder.editUsernameView(router: router)
        }
    }
}
