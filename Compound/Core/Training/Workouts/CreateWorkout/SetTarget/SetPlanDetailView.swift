import SwiftUI

struct SetPlanDetailDelegate {
    /// The set as the editor holds it when the sheet opens. The sheet is its only editor while it
    /// is open, so it keeps its own copy and hands each change back rather than reading a binding.
    let setTarget: SetTarget
    let onChange: @MainActor (SetTarget) -> Void
}

struct SetPlanDetailView: View {

    @State var presenter: SetPlanDetailPresenter

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Form {
            Section {
                Picker(selection: $presenter.setType) {
                    ForEach(presenter.kinds) { kind in
                        Text(presenter.kindTitle(kind)).tag(kind)
                    }
                } label: {
                    Text("Set Type")
                }
                .pickerStyle(.menu)
                .accessibilityLabel(presenter.setTypeAccessibilityLabel)

                if presenter.showsDrops {
                    dropRows
                }
                if presenter.showsMiniSets {
                    Stepper(presenter.miniSetCountTitle, value: $presenter.miniSetCount, in: presenter.miniSetCountRange)
                }
                if presenter.showsAMRAPTarget {
                    NumberField(String(localized: "Optional"), value: $presenter.amrapTargetReps, label: String(localized: "Target Reps"))
                }
                if presenter.showsPartialReps {
                    Picker("Partial Reps", selection: $presenter.partialReps) {
                        ForEach(presenter.partialRepsChoices, id: \.self) { reps in
                            Text(presenter.partialRepsTitle(reps)).tag(reps)
                        }
                    }
                    .pickerStyle(.menu)
                }
                if presenter.showsHoldSeconds {
                    Picker("Duration", selection: $presenter.holdSeconds) {
                        ForEach(presenter.holdSecondsChoices, id: \.self) { seconds in
                            Text(presenter.holdSecondsTitle(seconds)).tag(seconds)
                        }
                    }
                    .pickerStyle(.menu)
                }
            } footer: {
                Text("Drops and mini-sets count with their set. Progression plans from the first piece.")
            }
        }
        .navigationTitle(presenter.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) {
                    presenter.onDonePressed()
                }
            }
        }
        .onAppear {
            presenter.onViewAppear()
        }
    }

    @ViewBuilder
    private var dropRows: some View {
        Stepper(presenter.dropCountTitle, value: $presenter.dropCount, in: presenter.dropCountRange)

        // The three steps beside their label, or under it at the accessibility sizes.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.s))
            : AnyLayout(HStackLayout(spacing: Spacing.s))
        layout {
            Text("Each Drop")
                .frame(maxWidth: .infinity, alignment: .leading)
            // In a row while they fit unbroken, else one above the other.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.xs) { dropStepChips }
                VStack(alignment: .leading, spacing: 0) { dropStepChips }
            }
        }
        .accessibilityElement(children: .contain)

        NumberField(String(localized: "To failure"), value: $presenter.dropReps, label: String(localized: "Reps on Each Drop"))
    }

    private var dropStepChips: some View {
        ForEach(presenter.dropSteps, id: \.self) { percent in
            Button {
                presenter.onDropStepPressed(percent)
            } label: {
                Chip(presenter.dropStepTitle(percent), isSelected: presenter.dropStep == percent)
                    .fixedSize()
                    .chipTapTarget()
            }
            .buttonStyle(.plain)
        }
    }
}

extension CoreBuilder {

    func setPlanDetailView(router: AnyRouter, delegate: SetPlanDetailDelegate) -> some View {
        SetPlanDetailView(
            presenter: SetPlanDetailPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }

}

extension CoreRouter {

    func showSetPlanDetailView(delegate: SetPlanDetailDelegate) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.setPlanDetailView(router: router, delegate: delegate)
        }
    }

}

#Preview("Drop set") {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = SetPlanDetailDelegate(
        setTarget: SetTarget(setNumber: 3, minReps: 8, maxReps: 8, setType: .drop, dropCount: 2),
        onChange: { _ in }
    )

    return RouterView { router in
        builder.setPlanDetailView(router: router, delegate: delegate)
    }
}
