import SwiftUI

struct TrainingProgramDisclosureGroupDelegate {
    var trainingProgram: TrainingProgram
    /// Adds Delete beside Share in the row's menu, so it is not reachable by swipe alone.
    var onDelete: ((TrainingProgram) -> Void)?
    
    var eventParameters: [String: Any]? {
        nil
    }
}

struct TrainingProgramDisclosureGroupView: View {
    
    @State var presenter: TrainingProgramDisclosureGroupPresenter
    let delegate: TrainingProgramDisclosureGroupDelegate
    
    var body: some View {
        DisclosureGroup {
            // No chevron: these rows open nothing, and a chevron promised that they did.
            ForEach(delegate.trainingProgram.workoutTemplates) { workout in
                WorkoutTemplateRow(workoutTemplate: workout)
            }
            .listRowInsets(.leading, 0)
        } label: {
            TrainingProgramHeader(program: delegate.trainingProgram)
                .anyButton {
                    presenter.onSavedProgramPressed(delegate.trainingProgram)
                }
                .contextMenu {
                    Button("Share with Friends", systemImage: Symbol.share) {
                        presenter.onSharePressed(delegate.trainingProgram)
                    }
                    if let onDelete = delegate.onDelete {
                        Button("Delete Program", systemImage: Symbol.delete, role: .destructive) {
                            onDelete(delegate.trainingProgram)
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
    let delegate = TrainingProgramDisclosureGroupDelegate(trainingProgram: .mock)
    
    return RouterView { router in
        builder.trainingProgramDisclosureGroupView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func trainingProgramDisclosureGroupView(router: AnyRouter, delegate: TrainingProgramDisclosureGroupDelegate) -> some View {
        TrainingProgramDisclosureGroupView(
            presenter: TrainingProgramDisclosureGroupPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showTrainingProgramDisclosureGroupView(delegate: TrainingProgramDisclosureGroupDelegate) {
        router.showScreen(.push) { router in
            builder.trainingProgramDisclosureGroupView(router: router, delegate: delegate)
        }
    }
    
}
