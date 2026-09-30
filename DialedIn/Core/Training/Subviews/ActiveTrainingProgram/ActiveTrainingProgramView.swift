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
                let items = presenter.microcycleItems(program: delegate.program)
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
                .rowActions {
                    Button("Delete", systemImage: Symbol.delete, role: .destructive) {
                        presenter.onProgramDeletePressed(program: delegate.program)
                    }
                }
            }
        } header: {
            HStack(spacing: Spacing.s) {
                Text("Active Program")
                Spacer()
                Button("Previous Microcycle", systemImage: Symbol.previous) {
                    presenter.onPreviousCyclePressed()
                }
                .disabled(!presenter.canShowPreviousCycle)
                Text(presenter.microcycleHeaderText)
                    .monospacedDigit()
                Button("Next Microcycle", systemImage: Symbol.next) {
                    presenter.onNextCyclePressed()
                }
                .disabled(!presenter.canShowNextCycle)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
        .listSectionMargins(.top, 0)
    }

    @ViewBuilder
    private func microcycleItemRow(item: MicrocycleItem) -> some View {
        MicrocycleItemRow(item: item)
            .anyButton(.highlight) {
                presenter.onItemPressed(item)
            }
            .rowActions {
                if item.canSkip {
                    Button("Skip", systemImage: Symbol.skip) {
                        presenter.onSkipPressed(item)
                    }
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
