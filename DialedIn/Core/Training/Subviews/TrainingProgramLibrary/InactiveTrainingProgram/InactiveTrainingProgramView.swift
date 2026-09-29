import SwiftUI

struct InactiveTrainingProgramDelegate {
    
    var inactivePrograms: [TrainingProgram]
    /// Each row gets a trailing destructive swipe when this is set; the library passes its own
    /// delete confirmation so the alert and the delete stay on the screen that owns them.
    var onDelete: ((TrainingProgram) -> Void)?
    
    var eventParameters: [String: Any]? {
        nil
    }
}

struct InactiveTrainingProgramView<ProgramDisclosure: View>: View {
    
    @State var presenter: InactiveTrainingProgramPresenter
    let delegate: InactiveTrainingProgramDelegate
    
    @ViewBuilder var trainingProgramDisclosureGroup: (TrainingProgramDisclosureGroupDelegate) -> ProgramDisclosure
    
    var body: some View {
        Group {
            ForEach(delegate.inactivePrograms) { program in
                trainingProgramDisclosureGroup(
                    TrainingProgramDisclosureGroupDelegate(
                        trainingProgram: program
                    )
                )
                .swipeActions(edge: .trailing) {
                    if let onDelete = delegate.onDelete {
                        Button(role: .destructive) {
                            onDelete(program)
                        } label: {
                            Label("Delete", systemImage: "trash")
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
    let delegate = InactiveTrainingProgramDelegate(inactivePrograms: TrainingProgram.mocks)
    
    return RouterView { router in
        List {
            builder.inactiveTrainingProgramView(router: router, delegate: delegate)
        }
    }
}

extension CoreBuilder {
    
    func inactiveTrainingProgramView(router: AnyRouter, delegate: InactiveTrainingProgramDelegate) -> some View {
        InactiveTrainingProgramView(
            presenter: InactiveTrainingProgramPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate,
            trainingProgramDisclosureGroup: { delegate in
                self.trainingProgramDisclosureGroupView(router: router, delegate: delegate)
            }
        )
    }
    
}

extension CoreRouter {
    
    func showInactiveTrainingProgramView(delegate: InactiveTrainingProgramDelegate) {
        router.showScreen(.push) { router in
            builder.inactiveTrainingProgramView(router: router, delegate: delegate)
        }
    }
    
}
