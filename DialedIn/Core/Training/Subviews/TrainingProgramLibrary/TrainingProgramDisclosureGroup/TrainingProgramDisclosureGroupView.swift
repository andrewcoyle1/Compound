import SwiftUI

struct TrainingProgramDisclosureGroupDelegate {
    var trainingProgram: TrainingProgram
    
    var eventParameters: [String: Any]? {
        nil
    }
}

struct TrainingProgramDisclosureGroupView: View {
    
    @State var presenter: TrainingProgramDisclosureGroupPresenter
    let delegate: TrainingProgramDisclosureGroupDelegate
    
    var body: some View {
        DisclosureGroup {
            ForEach(delegate.trainingProgram.workoutTemplates) { workout in
                HStack {
                    WorkoutTemplateRow(workoutTemplate: workout)
                    Image(systemName: "chevron.right")
                }
            }
            .listRowInsets(.leading, 0)
        } label: {
            TrainingProgramHeader(program: delegate.trainingProgram)
                .anyButton {
                    presenter.onSavedProgramPressed(delegate.trainingProgram)
                }
                .contextMenu {
                    Button("Share with Friends", systemImage: "paperplane") {
                        presenter.onSharePressed(delegate.trainingProgram)
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
