import SwiftUI

struct DefineWorkoutWrapperDelegate {
    let name: String
    let gymProfile: GymProfileModel
    /// Set when editing: the saved model keeps this template's id so the save updates it in place.
    var workoutTemplate: WorkoutTemplateModel?
    /// Held by the name step, so going back to it and forward again keeps the exercises chosen here.
    var draftExercises: Binding<[WorkoutTemplateExercise]>?
}

struct DefineWorkoutWrapperView<DefineWorkout: View>: View {

    @State var presenter: DefineWorkoutWrapperPresenter
    let delegate: DefineWorkoutWrapperDelegate

    @ViewBuilder var defineWorkoutView: (DefineWorkoutDelegate) -> DefineWorkout

    var body: some View {
        let defineDelegate = DefineWorkoutDelegate(
            name: delegate.name,
            gymProfile: delegate.gymProfile,
            exercises: Binding(
                get: { presenter.exercises },
                set: { presenter.exercises = $0 }
            ),
            topSectionStyle: .standaloneWorkout
        )
        defineWorkoutView(defineDelegate)
            .onAppear {
                presenter.onViewAppear()
            }
            .onDisappear {
                presenter.onViewDisappear()
            }
            .bottomCTA {
                CallToActionButton(isLoading: presenter.isSaving) {
                    presenter.onConfirmPressed(delegate: self.delegate)
                } label: {
                    Text("Save")
                }
                .accessibilityIdentifier("DefineWorkoutWrapper.save")
                .disabled(!presenter.canSave)
            }
    }
}

extension CoreBuilder {
    
    func defineWorkoutWrapperView(router: AnyRouter, delegate: DefineWorkoutWrapperDelegate) -> some View {
        DefineWorkoutWrapperView(
            presenter: DefineWorkoutWrapperPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                exercises: delegate.workoutTemplate?.exercises ?? [],
                draft: delegate.draftExercises
            ),
            delegate: delegate,
            defineWorkoutView: { delegate in
                self.defineWorkoutView(router: router, delegate: delegate)
            }
        )
    }
    
}

extension CoreRouter {
    
    func showDefineWorkoutWrapperView(delegate: DefineWorkoutWrapperDelegate) {
        router.showScreen(.push) { router in
            builder.defineWorkoutWrapperView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = DefineWorkoutWrapperDelegate(name: "Sample Workout", gymProfile: GymProfileModel.mock)
    
    return RouterView { router in
        builder.defineWorkoutWrapperView(router: router, delegate: delegate)
    }
    
}
