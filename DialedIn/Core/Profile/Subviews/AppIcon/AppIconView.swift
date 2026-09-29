import SwiftUI

struct AppIconDelegate {
    
}

struct AppIconView: View {
    
    @State var presenter: AppIconPresenter
    let delegate: AppIconDelegate
    
    var body: some View {
        // Was three `CustomListCellView()` with no arguments — empty rows implying a choice of icons.
        FeatureUnavailableView(
            title: String(localized: "App Icon"),
            systemImage: "app.grid",
            summary: "Alternate app icons are not available yet. There is only one icon set in the asset catalogue, so there is nothing to switch between."
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
    
    func appIconView(router: AnyRouter, delegate: AppIconDelegate) -> some View {
        AppIconView(
            presenter: AppIconPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showAppIconView(delegate: AppIconDelegate) {
        router.showScreen(.push) { router in
            builder.appIconView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = AppIconDelegate()
    
    return RouterView { router in
        builder.appIconView(router: router, delegate: delegate)
    }
    
}
