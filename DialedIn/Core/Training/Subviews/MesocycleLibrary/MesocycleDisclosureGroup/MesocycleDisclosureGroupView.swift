import SwiftUI

struct MesocycleDisclosureGroupDelegate {
    var mesocycle: Mesocycle
    /// Adds Delete beside Share in the row's menu, so it is not reachable by swipe alone.
    var onDelete: ((Mesocycle) -> Void)?
    
    var eventParameters: [String: Any]? {
        nil
    }
}

struct MesocycleDisclosureGroupView: View {
    
    @State var presenter: MesocycleDisclosureGroupPresenter
    let delegate: MesocycleDisclosureGroupDelegate
    
    var body: some View {
        DisclosureGroup {
            // No chevron: these rows open nothing, and a chevron promised that they did.
            ForEach(delegate.mesocycle.workoutTemplates) { workout in
                WorkoutTemplateRow(workoutTemplate: workout)
            }
            .listRowInsets(.leading, 0)
        } label: {
            MesocycleHeader(mesocycle: delegate.mesocycle)
                .anyButton {
                    presenter.onSavedMesocyclePressed(delegate.mesocycle)
                }
                .contextMenu {
                    Button("Share with Friends", systemImage: Symbol.share) {
                        presenter.onSharePressed(delegate.mesocycle)
                    }
                    if let onDelete = delegate.onDelete {
                        Button("Delete Mesocycle", systemImage: Symbol.delete, role: .destructive) {
                            onDelete(delegate.mesocycle)
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
    let delegate = MesocycleDisclosureGroupDelegate(mesocycle: .mock)
    
    return RouterView { router in
        builder.mesocycleDisclosureGroupView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func mesocycleDisclosureGroupView(router: AnyRouter, delegate: MesocycleDisclosureGroupDelegate) -> some View {
        MesocycleDisclosureGroupView(
            presenter: MesocycleDisclosureGroupPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showMesocycleDisclosureGroupView(delegate: MesocycleDisclosureGroupDelegate) {
        router.showScreen(.push) { router in
            builder.mesocycleDisclosureGroupView(router: router, delegate: delegate)
        }
    }
    
}
