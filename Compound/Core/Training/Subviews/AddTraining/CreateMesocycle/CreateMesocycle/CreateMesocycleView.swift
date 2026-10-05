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
    
    /// Onboarding's training step. Building a mesocycle from nothing was the only way through,
    /// four screens before the user had trained once; the shipped programs are now offered first,
    /// with building one's own kept as the bottom button.
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Choose a Program")
                        .font(.display)
                        .accessibilityAddTraits(.isHeader)
                    Text("Start with a ready-made mesocycle, or build your own.")
                        .font(.rowTitle)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(.horizontal, 0)
            }

            if let recommended = presenter.recommendedProgram {
                Section {
                    programRow(recommended)
                } header: {
                    Text("Recommended for You")
                } footer: {
                    Text("Based on how often you said you exercise.")
                }
            }

            if !presenter.otherPrograms.isEmpty {
                Section(presenter.recommendedProgram == nil ? "Programs" : "More Programs") {
                    ForEach(presenter.otherPrograms) { program in
                        programRow(program)
                    }
                }
            }
        }
        .navigationTitle("Choose a Program")
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
                Text("Build My Own")
            }
            .accessibilityIdentifier("CreateProgram.continue")
        }
    }

    private func programRow(_ program: Mesocycle) -> some View {
        ListRowButton(
            title: program.name,
            subtitle: presenter.summary(of: program),
            systemImage: program.icon,
            tint: Color(hex: program.colour)
        ) {
            presenter.onProgramPressed(program, delegate: delegate)
        }
        .accessibilityIdentifier("CreateProgram.program.\(program.id)")
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
