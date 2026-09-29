import SwiftUI

struct AddTrainingDelegate {
    var onSelectProgram: (() -> Void)?
    var onSelectWorkout: (() -> Void)?
    var onSelectExercise: (() -> Void)?
}

struct AddTrainingView: View {
    
    @State var presenter: AddTrainingPresenter
    let delegate: AddTrainingDelegate
    
    var body: some View {
        List {
            Section {
                ListRowButton(title: String(localized: "New Program"), systemImage: Symbol.program) {
                    presenter.onNewProgramPressed()
                }
                ListRowButton(title: String(localized: "New Workout"), systemImage: Symbol.workout) {
                    presenter.onNewEmptyWorkoutPressed()
                }
                ListRowButton(title: String(localized: "New Exercise"), systemImage: Symbol.exercise) {
                    presenter.onNewExercisePressed()
                }
            }
            .listSectionMargins(.vertical, 0)
        }
        .navigationTitle("Add")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.dismissScreen()
            }
        }
    }
}

extension CoreBuilder {
    
    func addTrainingView(router: AnyRouter, delegate: AddTrainingDelegate) -> some View {
        AddTrainingView(
            presenter: AddTrainingPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showAddTrainingView(delegate: AddTrainingDelegate, onDismiss: (() -> Void)? = nil) {
        router.showScreen(.sheetConfig(config: .compact)) { router in
            builder.addTrainingView(router: router, delegate: delegate)
        }
    }

    func showAddTrainingViewZoom(delegate: AddTrainingDelegate, transitionId: String?, namespace: Namespace.ID) {
        router.showScreenWithZoomTransition(
            .sheetConfig(config: .compact),
            transitionID: transitionId,
            namespace: namespace) { router in
                builder.addTrainingView(router: router, delegate: delegate)
            }
    }

}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = AddTrainingDelegate()
    
    return RouterView { router in
        builder.addTrainingView(router: router, delegate: delegate)
    }
    
}
