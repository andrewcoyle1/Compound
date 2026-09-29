import SwiftUI

struct ProgramIconDelegate {
    let onComplete: (@Sendable () -> Void)?
    let name: String

    init(onComplete: (@Sendable () -> Void)? = nil, name: String) {
        self.onComplete = onComplete
        self.name = name
    }
}

struct ProgramIconView: View {
    
    @State var presenter: ProgramIconPresenter
    let delegate: ProgramIconDelegate
    
    var body: some View {
        VStack(spacing: Spacing.l) {
            Text("Choose an icon for this program.")
                .font(.sectionTitle)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ProgramColourIconGrid(
                colours: presenter.colours,
                icons: presenter.icons,
                selectedColour: presenter.selectedColour,
                selectedIcon: presenter.selectedIcon,
                onColourPressed: { presenter.onColourPressed(colour: $0) },
                onIconPressed: { presenter.onIconPressed(icon: $0) }
            )
            Spacer()
        }
        .padding(.top)
        .background(Color.canvas)
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
            .accessibilityIdentifier("ProgramIcon.continue")
        }
    }
}

extension CoreBuilder {
    func programIconView(router: AnyRouter, delegate: ProgramIconDelegate) -> some View {
        ProgramIconView(
            presenter: ProgramIconPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showProgramIconView(delegate: ProgramIconDelegate) {
        router.showScreen(.push) { router in
            builder.programIconView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = ProgramIconDelegate(name: "Preview Program")
    
    return RouterView { router in
        builder.programIconView(router: router, delegate: delegate)
    }
    
}
