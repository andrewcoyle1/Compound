//
//  WorkoutSessionRowPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/02/2026.
//

import SwiftUI

@Observable
@MainActor
class WorkoutSessionRowPresenter {

    private let interactor: WorkoutSessionRowInteractor
    private let router: WorkoutSessionRowRouter
    let reportFlow: ReportFlow
    let session: WorkoutSessionModel
    let author: UserModel
    private let sessionAuthorId: String

    private(set) var isLiked: Bool
    private(set) var likeCount: Int

    /// The lifts in this session that beat the author's earlier best, at most three.
    let personalRecords: [WorkoutSessionHighlights.PersonalRecord]
    /// Where this session falls in the author's week: 3 for their third workout that week.
    let weeklyWorkoutNumber: Int

    init(
        interactor: WorkoutSessionRowInteractor,
        router: WorkoutSessionRowRouter,
        delegate: WorkoutSessionRowDelegate
    ) {
        self.interactor = interactor
        self.router = router
        self.reportFlow = ReportFlow(interactor: interactor, router: router)
        self.session = delegate.session
        self.author = delegate.author
        self.sessionAuthorId = delegate.session.authorId
        self.isLiked = delegate.session.likedByUserIds.contains(interactor.currentUser?.userId ?? "")
        self.likeCount = delegate.session.likedByUserIds.count

        let history = interactor.workoutSessions(authoredBy: delegate.session.authorId)
        self.personalRecords = WorkoutSessionHighlights.personalRecords(in: delegate.session, priorSessions: history)
        self.weeklyWorkoutNumber = WorkoutSessionHighlights.weeklyWorkoutNumber(of: delegate.session, history: history)
    }

    var weeklyWorkoutText: String? {
        WorkoutSessionHighlights.weeklyWorkoutText(weeklyWorkoutNumber)
    }

    var streakText: String? {
        WorkoutSessionHighlights.streakText(session.streakCount)
    }

    func onWorkoutPressed() {
        router.showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate(workoutSession: session))
    }

    func onLikeButtonPressed() {
        guard let userId = interactor.currentUser?.userId else { return }
        let wasLiked = isLiked
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        Task {
            do {
                if isLiked {
                    try await interactor.likeSession(sessionId: session.id, authorId: sessionAuthorId, userId: userId)
                } else {
                    try await interactor.unlikeSession(sessionId: session.id, authorId: sessionAuthorId, userId: userId)
                }
            } catch {
                isLiked = wasLiked
                likeCount += wasLiked ? 1 : -1
            }
        }
    }

    func onCommentButtonPressed() {
        router.showCommentsView(delegate: CommentsDelegate(session: session))
    }

    /// The share button used to raise a "Not implemented yet." alert. There is no deep link for a
    /// session, so there is no URL to share — but the summary the row already displays is worth
    /// sharing on its own, and the view hands this to a `ShareLink`.
    var shareSummary: String {
        let workingSets = session.exercises.flatMap { $0.sets }.filter { !$0.isWarmup }
        // Every row counts towards the volume — both sides were lifted — but a left and a right
        // are one set, so the set count pairs them.
        let volume = workingSets.reduce(0.0) { $0 + (($1.weightKg ?? 0) * Double($1.reps ?? 0)) }
        let setCount = session.exercises.reduce(0) { $0 + $1.workingSetCount }
        var parts = [
            session.name,
            "\(session.exercises.count) exercises",
            String(localized: "\(setCount) sets")
        ]
        if volume > 0 {
            parts.append("\(Int(volume)) kg lifted")
        }
        return parts.joined(separator: " · ")
    }

    /// The reader cannot report their own workout.
    var canReport: Bool {
        guard let readerId = interactor.currentUser?.userId else { return false }
        return sessionAuthorId != readerId
    }

    /// The session note, for its author's eyes only: a note is a private reminder ("left
    /// shoulder twinged"), not a caption, so a follower's feed never shows it.
    var authorNote: String? {
        guard let readerId = interactor.currentUser?.userId, readerId == sessionAuthorId else { return nil }
        let trimmed = session.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    func onReportPressed() {
        guard canReport else { return }
        reportFlow.start(ReportedContent(type: .session, id: session.id, authorUserId: sessionAuthorId, noun: "workout"))
    }

    func onUserPressed() {
        router.showSocialProfileView(delegate: SocialProfileDelegate(user: author))
    }

    // MARK: Share Image

    /// The card shows the author by first name only, which is all a feed row already shows.
    var shareCardContent: ShareCardContent {
        ShareCardContent.make(session: session, author: author, personalRecords: personalRecords, weeklyWorkoutNumber: weeklyWorkoutNumber)
    }

    func onShareImagePressed(format: WorkoutShareCardView.Format) {
        let content = shareCardContent
        router.showLoadingModal()
        Task {
            let image = await ShareCardRenderer.renderCard(content, format: format)
            router.dismissModal()
            if let image {
                router.showShareSheet(items: [image])
            } else {
                router.showSimpleAlert(title: String(localized: "Unable to Create Image"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    // MARK: Copy Link

    /// The session's public web page, absent where that page would refuse it.
    var webLink: URL? {
        SessionWebLink.url(for: session, author: author)
    }

    func onCopyLinkPressed(_ link: URL) {
        UIPasteboard.general.url = link
        interactor.playHaptic(option: .success)
        interactor.trackEvent(event: Event.copyLink(sessionId: session.id))
    }

    // MARK: Save as Template

    /// Copies the card's workout into the reader's own library. Offered on every card, the reader's
    /// own included — saving a one-off session as something to repeat is just as useful.
    func onSaveAsTemplatePressed() {
        guard let userId = interactor.currentUser?.userId else {
            router.showSimpleAlert(title: String(localized: "Unable to Save Workout"), subtitle: String(localized: "Please try again."))
            return
        }
        guard let template = WorkoutSessionTemplateBuilder.template(
            from: session,
            availableExercises: interactor.allExercises,
            existingNames: interactor.allWorkoutTemplates.map(\.name),
            authorId: userId
        ) else {
            interactor.trackEvent(event: Event.saveAsTemplateUnresolved(sessionId: session.id))
            router.showSimpleAlert(title: String(localized: "None of these exercises are in your library"), subtitle: nil)
            return
        }
        Task {
            do {
                try await interactor.saveWorkoutTemplate(workoutTemplate: template, image: nil)
                interactor.trackEvent(event: Event.saveAsTemplateSuccess(sessionId: session.id, exerciseCount: template.exercises.count))
                router.showAlert(title: String(localized: "Saved to your workouts"), subtitle: template.name) {
                    AnyView(VStack {
                        Button("Open") { self.onOpenSavedTemplatePressed(template) }
                        Button("OK", role: .cancel) { }
                    })
                }
            } catch {
                interactor.trackEvent(event: Event.saveAsTemplateFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Save Workout"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    // MARK: Share

    /// The template the session was started from, when the reader has it — their own or a seeded
    /// one. Someone else's own template is not in the reader's library, so the option is hidden.
    var shareableTemplate: WorkoutTemplateModel? {
        guard let id = session.workoutTemplateId else { return nil }
        return interactor.allWorkoutTemplates.first { $0.id == id }
    }

    func onShareTemplatePressed(_ template: WorkoutTemplateModel) {
        router.showShareToFollowerView(delegate: ShareToFollowerDelegate(payload: .template(template)))
    }

    func onOpenSavedTemplatePressed(_ template: WorkoutTemplateModel) {
        router.showWorkoutTemplateDetailView(
            delegate: WorkoutTemplateDetailDelegate(workoutTemplate: template, trainingProgramId: nil, onStartWorkoutPressed: nil)
        )
    }

    enum Event: LoggableEvent {
        case saveAsTemplateSuccess(sessionId: String, exerciseCount: Int)
        case saveAsTemplateUnresolved(sessionId: String)
        case saveAsTemplateFail(error: Error)
        case copyLink(sessionId: String)

        var eventName: String {
            switch self {
            case .saveAsTemplateSuccess: return "WorkoutSessionRow_SaveAsTemplate_Success"
            case .saveAsTemplateUnresolved: return "WorkoutSessionRow_SaveAsTemplate_Unresolved"
            case .saveAsTemplateFail: return "WorkoutSessionRow_SaveAsTemplate_Fail"
            case .copyLink: return "WorkoutSessionRow_CopyLink"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .saveAsTemplateSuccess(let sessionId, let exerciseCount):
                return ["session_id": sessionId, "exercise_count": exerciseCount]
            case .saveAsTemplateUnresolved(let sessionId), .copyLink(let sessionId):
                return ["session_id": sessionId]
            case .saveAsTemplateFail(let error):
                return error.eventParameters
            }
        }

        var type: LogType {
            switch self {
            case .saveAsTemplateFail: return .severe
            default: return .analytic
            }
        }
    }
}
