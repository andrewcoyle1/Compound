import SwiftUI

struct EditUsernameView: View {

    @State var presenter: EditUsernamePresenter
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        Form {
            Section {
                HStack(spacing: Spacing.xxs) {
                    Text(verbatim: "@")
                        .foregroundStyle(.secondary)
                    TextField("username", text: $presenter.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .accessibilityIdentifier("UsernameField")
                        .focused($isFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            guard presenter.canSave else { return }
                            Task { await presenter.onSavePressed() }
                        }
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
                    Button(role: .confirm) {
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
            isFieldFocused = true
        }
        .onDisappear {
            presenter.onViewDisappear()
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
            InlineMessage(.warning, message)
        case .checking:
            HStack(spacing: Spacing.s) {
                ProgressView().controlSize(.mini)
                Text("Checking…")
            }
        case .available:
            Label("Available", systemImage: Symbol.success)
                .foregroundStyle(.success)
        case .taken:
            InlineMessage(.error, "Taken")
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
