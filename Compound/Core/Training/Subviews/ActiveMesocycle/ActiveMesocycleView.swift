import SwiftUI

struct ActiveMesocycleDelegate {
    var mesocycle: Mesocycle

    var eventParameters: [String: Any]? {
        nil
    }
}

struct ActiveMesocycleView: View {

    @State var presenter: ActiveMesocyclePresenter
    let delegate: ActiveMesocycleDelegate

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $presenter.activeMesocycleIsExpanded) {
                let items = presenter.microcycleItems(mesocycle: delegate.mesocycle)
                ForEach(items) { item in
                    microcycleItemRow(item: item)
                }
                .listRowInsets(.leading, 0)
            } label: {
                MesocycleHeader(
                    mesocycle: delegate.mesocycle,
                    isDeloadCycle: presenter.isDeloadCycle,
                    periodisationPhase: presenter.periodisationPhase
                )
                .anyButton(.press) {
                    presenter.onMesocyclePressed(mesocycle: delegate.mesocycle)
                }
                .rowActions {
                    Button("Delete", systemImage: Symbol.delete, role: .destructive) {
                        presenter.onMesocycleDeletePressed(mesocycle: delegate.mesocycle)
                    }
                }
            }
        } header: {
            HStack(spacing: Spacing.s) {
                Text("Active Mesocycle")
                Spacer()
                microcycleMenu
            }
        }
        .listSectionMargins(.top, 0)
    }

    private var microcycleMenu: some View {
        Menu {
            Picker("Microcycle", selection: Binding(
                get: { presenter.displayedCycleIndex },
                set: { presenter.onCycleSelected($0) }
            )) {
                ForEach(0..<presenter.cycleCount, id: \.self) { index in
                    Text(presenter.cycleMenuTitle(index)).tag(index)
                }
            }
        } label: {
            HStack(spacing: Spacing.xxs) {
                Text(presenter.microcycleHeaderText)
                    .monospacedDigit()
                Image(systemName: Symbol.choose)
                    .iconSize(.small)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .accessibilityLabel("Choose microcycle")
        .accessibilityValue(presenter.microcycleHeaderText)
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
    let delegate = ActiveMesocycleDelegate(mesocycle: Mesocycle.mock)

    return RouterView { router in
        List {
            builder.activeMesocycleView(router: router, delegate: delegate)
        }
    }
}

extension CoreBuilder {

    func activeMesocycleView(router: AnyRouter, delegate: ActiveMesocycleDelegate) -> some View {
        ActiveMesocycleView(
            presenter: ActiveMesocyclePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showActiveMesocycleView(delegate: ActiveMesocycleDelegate) {
        router.showScreen(.push) { router in
            builder.activeMesocycleView(router: router, delegate: delegate)
        }
    }

}
