import SwiftUI

struct NameMesocycleDelegate {
    let onComplete: (@Sendable () -> Void)?
    /// True when this is the first screen of the cover, which then needs the close button.
    var showsCloseButton: Bool

    init(onComplete: (@Sendable () -> Void)? = nil, showsCloseButton: Bool = false) {
        self.onComplete = onComplete
        self.showsCloseButton = showsCloseButton
    }
}

struct NameMesocycleView: View {
    
    @State var presenter: NameMesocyclePresenter
    let delegate: NameMesocycleDelegate

    @FocusState private var isNameFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField("Enter mesocycle name", text: $presenter.mesocycleName)
                    .focused($isNameFocused)
                    .submitLabel(.continue)
                    .onSubmit {
                        presenter.onNextPressed(delegate: delegate)
                    }
                    .accessibilityIdentifier("NameProgram.name")
            } header: {
                Text("Mesocycle Name")
            } footer: {
                Text("What would you like to name this mesocycle?")
            }
        }
        .navigationTitle("Create Mesocycle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if delegate.showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        presenter.onDismissPressed()
                    }
                    .accessibilityIdentifier("NameProgram.close")
                }
            }
        }
        .onAppear {
            presenter.onViewAppear()
            isNameFocused = true
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .bottomCTA {
            CallToActionButton {
                presenter.onNextPressed(delegate: delegate)
            } label: {
                Text("Continue")
            }
            .accessibilityIdentifier("NameProgram.continue")
            .disabled(!presenter.canSave)
        }
    }
}

extension CoreBuilder {
    
    func nameMesocycleView(router: AnyRouter, delegate: NameMesocycleDelegate) -> some View {
        NameMesocycleView(
            presenter: NameMesocyclePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showNameMesocycleView(delegate: NameMesocycleDelegate) {
        router.showScreen(.push) { router in
            builder.nameMesocycleView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = NameMesocycleDelegate()
    
    RouterView { router in
        builder.nameMesocycleView(router: router, delegate: delegate)
    }
    
}
