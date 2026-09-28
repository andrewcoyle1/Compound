import SwiftUI

struct ActiveTrainingProgramDelegate {
    var program: TrainingProgram

    var eventParameters: [String: Any]? {
        nil
    }
}

struct ActiveTrainingProgramView: View {

    @State var presenter: ActiveTrainingProgramPresenter
    let delegate: ActiveTrainingProgramDelegate

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $presenter.activeProgramIsExpanded) {
                let items = presenter.currentMicrocycleItems(program: delegate.program)
                ForEach(items) { item in
                    microcycleItemRow(item: item)
                }
                .listRowInsets(.leading, 0)
            } label: {
                TrainingProgramHeader(
                    program: delegate.program,
                    isDeloadCycle: presenter.isDeloadCycle,
                    periodisationPhase: presenter.periodisationPhase
                )
                .anyButton(.press) {
                    presenter.onProgramPressed(program: delegate.program)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        presenter.onProgramDeletePressed(program: delegate.program)
                    }
                }
            }
        } header: {
            HStack {
                Text("Active Program")
                Spacer()
                // Not a link: nothing opens from here, so it no longer draws as one.
                Text(presenter.microcycleHeaderText)
            }
        }
        .listSectionMargins(.top, 0)
    }

    @ViewBuilder
    private func microcycleItemRow(item: MicrocycleItem) -> some View {
        MicrocycleItemRow(item: item)
            .anyButton(.highlight) {
                if let sessionId = item.completedSessionId {
                    presenter.openCompletedSession(sessionId: sessionId)
                } else {
                    presenter.startWorkoutTemplateModelWorkout(item.workoutTemplate, in: item.trainingProgramId)
                }
            }
    }

}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = ActiveTrainingProgramDelegate(program: TrainingProgram.mock)

    return RouterView { router in
        List {
            builder.activeTrainingProgramView(router: router, delegate: delegate)
        }
    }
}

extension CoreBuilder {

    func activeTrainingProgramView(router: AnyRouter, delegate: ActiveTrainingProgramDelegate) -> some View {
        ActiveTrainingProgramView(
            presenter: ActiveTrainingProgramPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showActiveTrainingProgramView(delegate: ActiveTrainingProgramDelegate) {
        router.showScreen(.push) { router in
            builder.activeTrainingProgramView(router: router, delegate: delegate)
        }
    }

}
