import SwiftUI

struct CreateMesocycleDelegate {
    /// Set by onboarding, which pushes this flow and resumes when it finishes. Nil when the flow
    /// is a cover, which opens on the name screen with its own close button.
    let onComplete: (@Sendable () -> Void)?

    init(onComplete: (@Sendable () -> Void)? = nil) {
        self.onComplete = onComplete
    }
}

struct CreateMesocycleView: View {
    
    @State var presenter: CreateMesocyclePresenter
    let delegate: CreateMesocycleDelegate
    
    var body: some View {
        VStack(spacing: 0) {
            ImageLoaderView()
                .ignoresSafeArea()
                .frame(maxHeight: 400)
            // The heading sits under the hero image: an inline bar title over the image was
            // unreadable. `navigationTitle` stays for VoiceOver and the back menu.
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Create Mesocycle")
                    .font(.display)
                    .accessibilityAddTraits(.isHeader)
                Text("It's time to create a custom mesocycle.")
                    .font(.rowTitle)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .navigationTitle("Create Mesocycle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
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
            .accessibilityIdentifier("CreateProgram.continue")
        }
    }
}

extension CoreBuilder {

    /// From the library the cover opens straight on the name: the splash was a tap with nothing to
    /// decide. Onboarding pushes the flow and keeps the splash, as the introduction to the
    /// training part of setup.
    @ViewBuilder
    func createMesocycleView(router: AnyRouter, delegate: CreateMesocycleDelegate) -> some View {
        if delegate.onComplete == nil {
            nameMesocycleView(router: router, delegate: NameMesocycleDelegate(showsCloseButton: true))
        } else {
            CreateMesocycleView(
                presenter: CreateMesocyclePresenter(
                    interactor: interactor,
                    router: CoreRouter(router: router, builder: self)
                ),
                delegate: delegate
            )
        }
    }
}

extension CoreRouter {
    
    func showCreateMesocycleView(delegate: CreateMesocycleDelegate) {
        router.showScreen(.fullScreenCover) { router in
            builder.createMesocycleView(router: router, delegate: delegate)
        }
    }
    
    /// Reached from the goal summary's router once the gym profile step completes, which is
    /// two screens below the top. `.append` puts the flow on top of the stack; the default
    /// `.insert` would slot it in behind the gym screens.
    func showOnboardingMesocycleView(delegate: CreateMesocycleDelegate) {
        router.showScreen(.push, location: .append) { router in
            builder.createMesocycleView(router: router, delegate: delegate)
        }
    }

}

#Preview("Sheet presentations") {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = CreateMesocycleDelegate()
    
    return RouterView { router in
        builder.createMesocycleView(router: router, delegate: delegate)
    }
    
}

#Preview("Onboarding presentations") {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = CreateMesocycleDelegate(onComplete: { })
    
    return RouterView { router in
        builder.createMesocycleView(router: router, delegate: delegate)
    }
    
}
