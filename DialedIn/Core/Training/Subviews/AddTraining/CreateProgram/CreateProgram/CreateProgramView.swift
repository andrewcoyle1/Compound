import SwiftUI

struct CreateProgramDelegate {
    /// Set by onboarding, which pushes this flow and resumes when it finishes. Nil when the flow
    /// is a cover, which is when it needs its own close button.
    let onComplete: (@Sendable () -> Void)?

    init(onComplete: (@Sendable () -> Void)? = nil) {
        self.onComplete = onComplete
    }
}

struct CreateProgramView: View {
    
    @State var presenter: CreateProgramPresenter
    let delegate: CreateProgramDelegate
    
    var body: some View {
        VStack(spacing: 0) {
            ImageLoaderView()
                .ignoresSafeArea()
                .frame(maxHeight: 400)
            Text("It's time to create a custom workout program.")
                .font(.rowTitle)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
            Spacer()
        }
        .navigationTitle("Create Program")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .toolbar {
            toolbarContent
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
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // The library entry passed no dismiss closure, so its cover had no way out but to finish.
        if delegate.onComplete == nil {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onDismissPressed()
                }
                .accessibilityIdentifier("CreateProgram.close")
            }
        }
    }
}

extension CoreBuilder {
    
    func createProgramView(router: AnyRouter, delegate: CreateProgramDelegate) -> some View {
        CreateProgramView(
            presenter: CreateProgramPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    
    func showCreateProgramView(delegate: CreateProgramDelegate) {
        router.showScreen(.fullScreenCover) { router in
            builder.createProgramView(router: router, delegate: delegate)
        }
    }
    
    /// Reached from the goal summary's router once the gym profile step completes, which is
    /// two screens below the top. `.append` puts the flow on top of the stack; the default
    /// `.insert` would slot it in behind the gym screens.
    func showOnboardingTrainingProgramView(delegate: CreateProgramDelegate) {
        router.showScreen(.push, location: .append) { router in
            builder.createProgramView(router: router, delegate: delegate)
        }
    }

}

#Preview("Sheet presentations") {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = CreateProgramDelegate()
    
    return RouterView { router in
        builder.createProgramView(router: router, delegate: delegate)
    }
    
}

#Preview("Onboarding presentations") {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = CreateProgramDelegate(onComplete: { })
    
    return RouterView { router in
        builder.createProgramView(router: router, delegate: delegate)
    }
    
}
