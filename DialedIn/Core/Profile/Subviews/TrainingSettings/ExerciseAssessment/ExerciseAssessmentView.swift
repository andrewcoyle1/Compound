import SwiftUI

struct ExerciseAssessmentDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct ExerciseAssessmentView: View {
    
    @State var presenter: ExerciseAssessmentPresenter
    let delegate: ExerciseAssessmentDelegate
    
    var body: some View {
        // Was `Text("Hello, World!")`. What the assessment actually is has not been decided.
        FeatureUnavailableView(
            title: String(localized: "Exercise Assessment"),
            systemImage: "figure.strengthtraining.traditional",
            summary: "Guided strength assessments are not available yet. The plan is to estimate your working weights from a short set of test lifts, so a new programme starts at the right load."
        )
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }
}

extension CoreBuilder {
    
    func exerciseAssessmentView(router: AnyRouter, delegate: ExerciseAssessmentDelegate) -> some View {
        ExerciseAssessmentView(
            presenter: ExerciseAssessmentPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showExerciseAssessmentView(delegate: ExerciseAssessmentDelegate) {
        router.showScreen(.push) { router in
            builder.exerciseAssessmentView(router: router, delegate: delegate)
        }
    }
    
}
