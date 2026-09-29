import SwiftUI

struct SiriDelegate {
    
}

struct SiriView: View {
    
    @State var presenter: SiriPresenter
    let delegate: SiriDelegate
    
    var body: some View {
        // The seven rows that were here ("Speak Remaining Goals", "Log Beer") were plain Text styled as
    // settings, doing nothing. They described intent, not behaviour.
        FeatureUnavailableView(
            title: String(localized: "Siri"),
            systemImage: "siri",
            summary: "Asking Siri to log a meal, start a workout or read back your remaining macros is not available yet. It needs an App Intents extension, which the app does not ship."
        )
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }
}

extension CoreBuilder {
    
    func siriView(router: AnyRouter, delegate: SiriDelegate) -> some View {
        SiriView(
            presenter: SiriPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showSiriView(delegate: SiriDelegate) {
        router.showScreen(.push) { router in
            builder.siriView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = SiriDelegate()
    
    return RouterView { router in
        builder.siriView(router: router, delegate: delegate)
    }
    
}
