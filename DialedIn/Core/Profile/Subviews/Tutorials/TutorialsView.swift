import SwiftUI

struct TutorialsDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct TutorialsView: View {
    
    @State var presenter: TutorialsPresenter
    let delegate: TutorialsDelegate
    
    var body: some View {
        // Was `Text("Hello, World!")` under a "Reset Tutorials" header, with a Reset CTA wired to an
        // empty presenter function. Nothing in the app tracks tutorial progress, so nothing to reset.
        FeatureUnavailableView(
            title: String(localized: "Tutorials"),
            systemImage: "book",
            summary: "There are no tutorials to reset yet. When the app starts showing first-run guidance, this is where you will be able to see it again."
        )
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }
}

extension CoreBuilder {
    
    func tutorialsView(router: AnyRouter, delegate: TutorialsDelegate) -> some View {
        TutorialsView(
            presenter: TutorialsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showTutorialsView(delegate: TutorialsDelegate) {
        router.showScreen(.push) { router in
            builder.tutorialsView(router: router, delegate: delegate)
        }
    }
    
}
