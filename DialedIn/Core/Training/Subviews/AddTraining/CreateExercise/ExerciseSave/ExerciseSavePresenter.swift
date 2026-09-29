import SwiftUI

@Observable
@MainActor
class ExerciseSavePresenter {
    
    private let interactor: ExerciseSaveInteractor
    private let router: ExerciseSaveRouter

    private(set) var isSaving: Bool = false

    var currentUser: UserModel? {
        interactor.currentUser
    }
    
    init(interactor: ExerciseSaveInteractor, router: ExerciseSaveRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onCreatePressed(delegate: ExerciseSaveDelegate) {
        guard !isSaving else { return }
        interactor.trackEvent(event: Event.createExerciseStart)

        // The whole wizard ends here, so a silent return threw away everything the user entered
        // and said nothing — to them or to us. The user document arrives on the sync engine's own
        // task, so this is reachable rather than theoretical.
        guard let userId = currentUser?.userId else {
            interactor.trackEvent(event: Event.createExerciseFail(error: ExerciseSaveError.noCurrentUser))
            router.showSimpleAlert(title: String(localized: "Unable to Create Exercise"), subtitle: String(localized: "Please try again."))
            return
        }

        let model = ExerciseModel(from: delegate, authorId: userId)
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await interactor.saveExerciseModel(exercise: model, image: nil)
                interactor.trackEvent(event: Event.createExerciseSuccess)
                router.dismissEnvironment()
            } catch {
                interactor.trackEvent(event: Event.createExerciseFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Create Exercise"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    func onViewAppear(delegate: ExerciseSaveDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: ExerciseSaveDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
}

extension ExerciseSavePresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: ExerciseSaveDelegate)
        case onDisappear(delegate: ExerciseSaveDelegate)
        case createExerciseStart
        case createExerciseSuccess
        case createExerciseFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:                 return "ExerciseSaveView_Appear"
            case .onDisappear:              return "ExerciseSaveView_Disappear"
            case .createExerciseStart:      return "CreateExercise_Start"
            case .createExerciseSuccess:    return "CreateExercise_Success"
            case .createExerciseFail:       return "CreateExercise_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .createExerciseFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .createExerciseFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}

enum ExerciseSaveError: LocalizedError {
    case noCurrentUser

    var errorDescription: String? {
        switch self {
        case .noCurrentUser:
            return String(localized: "No signed-in user to own the exercise")
        }
    }
}
