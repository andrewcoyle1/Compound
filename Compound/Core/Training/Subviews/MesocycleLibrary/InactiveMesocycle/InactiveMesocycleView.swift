import SwiftUI

struct InactiveMesocycleDelegate {
    
    var inactiveMesocycles: [Mesocycle]
    /// Each row gets a trailing destructive swipe when this is set; the library passes its own
    /// delete confirmation so the alert and the delete stay on the screen that owns them.
    var onDelete: ((Mesocycle) -> Void)?
    
    var eventParameters: [String: Any]? {
        nil
    }
}

struct InactiveMesocycleView<MesocycleDisclosure: View>: View {
    
    @State var presenter: InactiveMesocyclePresenter
    let delegate: InactiveMesocycleDelegate
    
    @ViewBuilder var mesocycleDisclosureGroup: (MesocycleDisclosureGroupDelegate) -> MesocycleDisclosure
    
    var body: some View {
        Group {
            ForEach(delegate.inactiveMesocycles) { mesocycle in
                mesocycleDisclosureGroup(
                    MesocycleDisclosureGroupDelegate(
                        mesocycle: mesocycle,
                        onDelete: delegate.onDelete
                    )
                )
                .swipeActions(edge: .trailing) {
                    if let onDelete = delegate.onDelete {
                        Button(role: .destructive) {
                            onDelete(mesocycle)
                        } label: {
                            Label("Delete", systemImage: Symbol.delete)
                        }
                    }
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
    let delegate = InactiveMesocycleDelegate(inactiveMesocycles: Mesocycle.mocks)
    
    return RouterView { router in
        List {
            builder.inactiveMesocycleView(router: router, delegate: delegate)
        }
    }
}

extension CoreBuilder {
    
    func inactiveMesocycleView(router: AnyRouter, delegate: InactiveMesocycleDelegate) -> some View {
        InactiveMesocycleView(
            presenter: InactiveMesocyclePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate,
            mesocycleDisclosureGroup: { delegate in
                self.mesocycleDisclosureGroupView(router: router, delegate: delegate)
            }
        )
    }
    
}

extension CoreRouter {
    
    func showInactiveMesocycleView(delegate: InactiveMesocycleDelegate) {
        router.showScreen(.push) { router in
            builder.inactiveMesocycleView(router: router, delegate: delegate)
        }
    }
    
}
