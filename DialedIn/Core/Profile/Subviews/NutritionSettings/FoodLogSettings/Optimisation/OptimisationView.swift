import SwiftUI

struct OptimisationDelegate { }

struct OptimisationView: View {

    @State var presenter: OptimisationPresenter
    let delegate: OptimisationDelegate

    var body: some View {
        List {
            Section {
                CustomToggleView(
                    title: String(localized: "Quick Add"),
                    subtitle: String(localized: "Use default portion and skip the amount entry screen"),
                    bool: $presenter.quickAddEnabled
                )
            }
        }
        .navigationTitle("Optimisation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
    }
}

extension CoreBuilder {

    func optimisationView(router: AnyRouter, delegate: OptimisationDelegate) -> some View {
        OptimisationView(
            presenter: OptimisationPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = OptimisationDelegate()

    return RouterView { router in
        builder.optimisationView(router: router, delegate: delegate)
    }
}
