import SwiftUI

struct NameProgramDelegate {
    let onComplete: (@Sendable () -> Void)?
    
    init(onComplete: (@Sendable () -> Void)? = nil) {
        self.onComplete = onComplete
    }
}

struct NameProgramView: View {
    
    @State var presenter: NameProgramPresenter
    let delegate: NameProgramDelegate
    
    var body: some View {
        List {
            Section {
                TextField("Enter program name", text: $presenter.programName)
                    .accessibilityIdentifier("NameProgram.name")
            } header: {
                Text("Program Name")
            } footer: {
                Text("What would you like to name this program?")
            }
        }
        .navigationTitle("Create Program")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
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
    
    func nameProgramView(router: AnyRouter, delegate: NameProgramDelegate) -> some View {
        NameProgramView(
            presenter: NameProgramPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showNameProgramView(delegate: NameProgramDelegate) {
        router.showScreen(.push) { router in
            builder.nameProgramView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = NameProgramDelegate()
    
    RouterView { router in
        builder.nameProgramView(router: router, delegate: delegate)
    }
    
}
