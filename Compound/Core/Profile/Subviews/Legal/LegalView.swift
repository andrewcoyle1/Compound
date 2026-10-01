import SwiftUI

struct LegalDelegate {
    
}

struct LegalView: View {
    
    @State var presenter: LegalPresenter
    let delegate: LegalDelegate
    
    var body: some View {
        List {
            Section {
                ForEach(LegalDocument.allCases) { document in
                    legalRow(document)
                }
            } header: {
                Text("Agreements")
            }
        }
        .navigationTitle("Legal")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    /// Opens the document in the browser. A row whose URL will not parse is shown disabled rather
    /// than as a live link that goes nowhere — which is what all four were before.
    @ViewBuilder
    private func legalRow(_ document: LegalDocument) -> some View {
        if let url = document.url {
            Link(destination: url) {
                ListRow(title: document.title, accessory: .custom(AnyView(
                    Image(systemName: "arrow.up.right")
                        .font(.label)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                )))
            }
            .foregroundStyle(.primary)
            .simultaneousGesture(TapGesture().onEnded {
                presenter.onDocumentPressed(document)
            })
        } else {
            Text(document.title)
                .foregroundStyle(.secondary)
        }
    }
}

extension CoreBuilder {
    
    func legalView(router: AnyRouter, delegate: LegalDelegate) -> some View {
        LegalView(
            presenter: LegalPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showLegalView(delegate: LegalDelegate) {
        router.showScreen(.push) { router in
            builder.legalView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = LegalDelegate()
    
    return RouterView { router in
        builder.legalView(router: router, delegate: delegate)
    }
    
}
