//
//  SharedItemPresenter.swift
//  DialedIn
//

import SwiftUI

@Observable
@MainActor
class SharedItemPresenter {
    private let interactor: SharedItemInteractor
    private let router: SharedItemRouter
    let delegate: SharedItemDelegate

    private(set) var status: ShareModel.Status
    private(set) var isWorking: Bool = false

    var isAnswered: Bool {
        status != .pending
    }

    /// A template shows as itself; a program as its days.
    var templates: [WorkoutTemplateModel] {
        switch delegate.share.payload {
        case .template(let template): [template]
        case .program(let program): program.workoutTemplates
        }
    }

    init(interactor: SharedItemInteractor, router: SharedItemRouter, delegate: SharedItemDelegate) {
        self.interactor = interactor
        self.router = router
        self.delegate = delegate
        self.status = delegate.share.status
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear(kind: delegate.share.payload.kind))
    }

    /// Custom exercises first, so the copy never points at an exercise the recipient does not have;
    /// the share is marked accepted last, so a failure part-way leaves it pending to try again.
    func onAddToLibraryPressed() {
        guard !isWorking, let userId = interactor.userId else { return }
        isWorking = true
        let share = delegate.share
        Task {
            do {
                let copy = SharedItemCopier.copy(share.payload, recipientId: userId, library: interactor.allExercises)
                for exercise in copy.newExercises {
                    try await interactor.saveExerciseModel(exercise: exercise, image: nil)
                }
                switch copy.payload {
                case .template(let template):
                    try await interactor.saveWorkoutTemplate(workoutTemplate: template, image: nil)
                case .program(let program):
                    try await interactor.saveTrainingProgram(trainingProgram: program)
                }
                try await interactor.updateShareStatus(.accepted, id: share.id)
                status = .accepted
                interactor.trackEvent(event: Event.acceptSuccess(kind: share.payload.kind))
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.answerFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to add"), subtitle: String(localized: "Please try again."))
            }
            isWorking = false
        }
    }

    func onDismissSharePressed() {
        guard !isWorking else { return }
        isWorking = true
        let id = delegate.share.id
        Task {
            do {
                try await interactor.updateShareStatus(.dismissed, id: id)
                status = .dismissed
                interactor.trackEvent(event: Event.dismissSuccess)
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.answerFail(error: error))
                router.showSimpleAlert(title: "Unable to dismiss", subtitle: "Please try again.")
            }
            isWorking = false
        }
    }

    func onClosePressed() {
        router.dismissScreen()
    }
}

extension SharedItemPresenter {
    enum Event: LoggableEvent {
        case onAppear(kind: String)
        case acceptSuccess(kind: String)
        case dismissSuccess
        case answerFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:         return "SharedItemView_Appear"
            case .acceptSuccess:    return "SharedItemView_Accept_Success"
            case .dismissSuccess:   return "SharedItemView_Dismiss_Success"
            case .answerFail:       return "SharedItemView_Answer_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let kind), .acceptSuccess(let kind):
                return ["kind": kind]
            case .answerFail(let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .answerFail: return .severe
            default: return .analytic
            }
        }
    }
}
