import SwiftUI

struct AboutDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct AboutView: View {
    
    @State var presenter: AboutPresenter
    let delegate: AboutDelegate
    
    var body: some View {
        ScrollView {
            Text("Compound is your training and nutrition platform. Every session builds on the last. You are currently on version \(presenter.appVersion) (\(presenter.appBuild)).")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
        }
        .navigationTitle("About Compound")
        .navigationBarTitleDisplayMode(.inline)
        .bottomCTA {
            CallToActionButton(isPrimaryAction: false) {
                presenter.onLicencesPressed()
            } label: {
                Text("View Licences")
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onDismissPressed()
                }
            }
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = AboutDelegate()
    
    return RouterView { router in
        builder.aboutView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func aboutView(router: AnyRouter, delegate: AboutDelegate) -> some View {
        AboutView(
            presenter: AboutPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showAboutView(delegate: AboutDelegate) {
        router.showScreen(.sheetConfig(config: .compact)) { router in
            builder.aboutView(router: router, delegate: delegate)
        }
    }
    
}
