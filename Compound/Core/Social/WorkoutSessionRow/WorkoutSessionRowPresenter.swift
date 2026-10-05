//
//  WorkoutSessionRowPresenter.swift
//  Compound
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

    // MARK: - Stats

    private var workingSets: [WorkoutSetModel] {
        session.exercises.flatMap { $0.sets }.filter { !$0.isWarmup }
    }

    var workingSetCount: Int { workingSets.count }

    /// Working sets' weight × reps, `nil` when nothing was lifted. Tonnes from 1,000 kg up.
    var volumeText: String? {
        let kilograms = workingSets.reduce(0) { $0 + ($1.volumeKg ?? 0) }
        guard kilograms > 0 else { return nil }
        // ponytail: tonnes have no `Format` function; add `Format.volume` if a second screen needs it.
        guard kilograms < 1000 else { return "\((kilograms / 1000).formatted(.number.precision(.fractionLength(1)))) t" }
        return Format.weight(kg: kilograms, unit: WeightUnitPreference.kilograms)
    }

    var durationText: String? {
        session.activeDuration.map { Format.duration($0) }
    }

    /// "3 × 10 @ 80 kg" for three working sets of ten: sets a side count once.
    func setsDescription(for exercise: WorkoutExerciseModel) -> String {
        guard let first = exercise.workingSets.first else { return String(localized: "\(exercise.setTargets.count) sets") }
        let count = exercise.workingSetCount
        guard let detail = Self.setDetail(first, mode: exercise.trackingMode) else { return String(localized: "\(count) sets") }
        return "\(count) × \(detail)"
    }

    private static func setDetail(_ set: WorkoutSetModel, mode: TrackingMode) -> String? {
        switch mode {
        case .weightReps:
            guard let reps = set.reps else { return nil }
            return set.weightKg.map { "\(reps) @ \(Format.weight(kg: $0, unit: WeightUnitPreference.kilograms))" } ?? "\(reps)"
        case .repsOnly:
            return set.reps.map { "\($0)" }
        case .timeOnly:
            return set.durationSec.map { Format.duration(TimeInterval($0)) }
        case .distanceTime:
            return set.distanceMeters.map { Format.distance(meters: $0, unit: .kilometers) }
        }
    }

    func onWorkoutPressed() {
        router.showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate(workoutSession: session))
    }

    func onLikeButtonPressed() {
        guard let userId = interactor.currentUser?.userId else { return }
        let wasLiked = isLiked
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        let liking = isLiked
        interactor.trackEvent(event: Event.likeStart(liking: liking))
        Task {
            do {
                if isLiked {
                    try await interactor.likeSession(sessionId: session.id, authorId: sessionAuthorId, userId: userId)
                } else {
                    try await interactor.unlikeSession(sessionId: session.id, authorId: sessionAuthorId, userId: userId)
                }
                interactor.trackEvent(event: Event.likeSuccess(liking: liking))
            } catch {
                interactor.trackEvent(event: Event.likeFail(liking: liking, error: error))
                isLiked = wasLiked
                likeCount += wasLiked ? 1 : -1
                interactor.playHaptic(option: .error)
            }
        }
    }

    func onCommentButtonPressed() {
        router.showCommentsView(delegate: CommentsDelegate(session: session))
    }

    /// The Share button's message beside `webLink`, or all it sends where there is no link.
    var shareSummary: String {
        let workingSets = session.exercises.flatMap { $0.sets }.filter { !$0.isWarmup }
        // Every row counts towards the volume — both sides were lifted — but a left and a right
        // are one set, so the set count pairs them.
        let volume = workingSets.reduce(0.0) { $0 + ($1.volumeKg ?? 0) }
        let setCount = session.exercises.reduce(0) { $0 + $1.workingSetCount }
        var parts = [
            session.name,
            String(localized: "\(session.exercises.count) exercises"),
            String(localized: "\(setCount) sets")
        ]
        if volume > 0 {
            parts.append(String(localized: "\(Int(volume)) kg lifted"))
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

    /// Rendering the share image is a read, not a write — the More button shows its own spinner
    /// instead of a modal blocking the whole screen for it.
    private(set) var isRenderingShareImage = false

    func onShareImagePressed(format: WorkoutShareCardView.Format) {
        let content = shareCardContent
        isRenderingShareImage = true
        interactor.trackEvent(event: Event.shareImageStart)
        Task {
            let image = await ShareCardRenderer.renderCard(content, format: format)
            isRenderingShareImage = false
            if let image {
                interactor.trackEvent(event: Event.shareImageSuccess)
                router.showShareSheet(items: [image])
            } else {
                interactor.trackEvent(event: Event.shareImageFail)
                router.showSimpleAlert(title: String(localized: "Unable to Create Image"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    // MARK: Link

    /// The session's public web page, absent where that page would refuse it.
    var webLink: URL? {
        SessionWebLink.url(for: session, author: author)
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
        interactor.trackEvent(event: Event.saveAsTemplateStart)
        Task {
            do {
                try await interactor.saveWorkoutTemplate(workoutTemplate: template, image: nil)
                interactor.trackEvent(event: Event.saveAsTemplateSuccess(sessionId: session.id, exerciseCount: template.exercises.count))
                interactor.showAppToast(AppToast(style: .success, message: String(localized: "Saved \(template.name) to your workouts")))
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

    enum Event: LoggableEvent {
        case saveAsTemplateStart
        case saveAsTemplateSuccess(sessionId: String, exerciseCount: Int)
        case saveAsTemplateUnresolved(sessionId: String)
        case saveAsTemplateFail(error: Error)
        case likeStart(liking: Bool)
        case likeSuccess(liking: Bool)
        case likeFail(liking: Bool, error: Error)
        case shareImageStart
        case shareImageSuccess
        case shareImageFail

        var eventName: String {
            switch self {
            case .saveAsTemplateStart: return "WorkoutSessionRow_SaveAsTemplate_Start"
            case .saveAsTemplateSuccess: return "WorkoutSessionRow_SaveAsTemplate_Success"
            case .saveAsTemplateUnresolved: return "WorkoutSessionRow_SaveAsTemplate_Unresolved"
            case .saveAsTemplateFail: return "WorkoutSessionRow_SaveAsTemplate_Fail"
            case .likeStart(let liking): return liking ? "WorkoutSessionRow_Like_Start" : "WorkoutSessionRow_Unlike_Start"
            case .likeSuccess(let liking): return liking ? "WorkoutSessionRow_Like_Success" : "WorkoutSessionRow_Unlike_Success"
            case .likeFail(let liking, _): return liking ? "WorkoutSessionRow_Like_Fail" : "WorkoutSessionRow_Unlike_Fail"
            case .shareImageStart: return "WorkoutSessionRow_ShareImage_Start"
            case .shareImageSuccess: return "WorkoutSessionRow_ShareImage_Success"
            case .shareImageFail: return "WorkoutSessionRow_ShareImage_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .saveAsTemplateSuccess(let sessionId, let exerciseCount):
                return ["session_id": sessionId, "exercise_count": exerciseCount]
            case .saveAsTemplateUnresolved(let sessionId):
                return ["session_id": sessionId]
            case .saveAsTemplateFail(let error), .likeFail(_, let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .saveAsTemplateFail, .likeFail, .shareImageFail: return .severe
            default: return .analytic
            }
        }
    }
}
