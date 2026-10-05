//
//  WorkoutSessionDetailPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

@Observable
@MainActor
class WorkoutSessionDetailPresenter {
    private let interactor: WorkoutSessionDetailInteractor
    private let router: WorkoutSessionDetailRouter

    private(set) var isEditMode = false

    /// Who logged this workout, once it is known. The header used to be handed `UserModel.mock`,
    /// so every session — including a stranger's from the feed — was shown as written by a
    /// fictional user, whose profile it opened on a tap.
    private(set) var author: UserModel?
        
    var isSaving: Bool = false
    var isLoading: Bool {
        isSaving
    }
    
    var selectedExerciseModels: [WorkoutTemplateExercise] = []
    
    /// Whether the signed-in user wrote this workout, and so may edit or delete it.
    ///
    /// Both sides are optional, and comparing them directly made a signed-out reader the author of
    /// an unattributed session, since `nil == nil`. Nobody owns a workout with no author.
    func isAuthor(sessionAuthorId: String?) -> Bool {
        guard let userId = interactor.currentUser?.userId, let sessionAuthorId else { return false }
        return userId == sessionAuthorId
    }
        
    /// What was last written to the backend from this screen. A timing edit saves the whole
    /// session, so after one the screen has nothing unsaved even though it no longer matches what
    /// it opened with.
    private var lastSavedSession: WorkoutSessionModel?

    func hasUnsavedChanges(session: WorkoutSessionModel, editedSession: WorkoutSessionModel) -> Bool {
        editedSession != (lastSavedSession ?? session)
    }
    
    /// The last page of the workout tracker rather than a screen browsed to: leaving it closes the
    /// tracker's cover, not just this page.
    private let isWorkoutSummary: Bool

    init(
        interactor: WorkoutSessionDetailInteractor,
        router: WorkoutSessionDetailRouter,
        isWorkoutSummary: Bool = false
    ) {
        self.interactor = interactor
        self.router = router
        self.isWorkoutSummary = isWorkoutSummary
    }

    func onViewAppear(delegate: WorkoutSessionDetailDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: WorkoutSessionDetailDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func loadAuthor(for session: WorkoutSessionModel) async {
        let authorId = session.authorId
        if let currentUser = interactor.currentUser, currentUser.userId == authorId {
            author = currentUser
            return
        }
        // An author who cannot be read stays unknown: no header is better than someone else's name.
        do {
            author = try await interactor.getUser(userId: authorId)
        } catch {
            author = nil
            interactor.trackEvent(event: Event.loadAuthorFail(error: error))
        }
    }

    func totalSets(session: WorkoutSessionModel) -> Int {
        session
            .exercises
            .flatMap { $0.sets }
            .filter { !$0.isWarmup }
            .count
    }
    
    func totalVolume(session: WorkoutSessionModel) -> Double {
        session
            .exercises
            .flatMap { $0.sets }
            .filter { !$0.isWarmup }
            .compactMap { set -> Double? in
                guard let weight = set.weightKg, let reps = set.reps else { return nil }
                return weight * Double(reps)
            }
            .reduce(0.0, +)
    }
    
    /// Exercises are logged in different units, so the total is shown in the reader's own
    /// body-weight unit. Every set is stored in kilograms, so summing first and converting once is
    /// the same as converting each exercise. It used to be labelled kg whatever the user used.
    func volumeFormatted(session: WorkoutSessionModel) -> String {
        let volume = totalVolume(session: session)
        let unit = interactor.currentUser?.submittedWeightUnitPreference ?? .kilograms
        return volume > 0 ? Format.weight(kg: volume, unit: unit) : Format.placeholder
    }
    
    /// The weight unit this exercise is shown in.
    func weightUnit(for templateId: String) -> ExerciseWeightUnit {
        interactor.getPreference(templateId: templateId).weightUnit
    }

    /// The distance unit this exercise is shown in. Read-only, like `weightUnit(for:)`.
    func distanceUnit(for templateId: String) -> ExerciseDistanceUnit {
        interactor.getPreference(templateId: templateId).distanceUnit
    }

    /// The line under each exercise: its own working sets and volume, in the exercise's unit.
    /// It used to count the session's exercises as the sets and always said "kg".
    func exerciseSummary(_ exercise: WorkoutExerciseModel) -> String {
        let workingSets = exercise.workingSets
        let unit = weightUnit(for: exercise.templateId)
        let volumeKg = workingSets
            .compactMap { set -> Double? in
                guard let weight = set.weightKg, let reps = set.reps else { return nil }
                return weight * Double(reps)
            }
            .reduce(0.0, +)
        return String(localized: "\(String(localized: "\(workingSets.pairedSetCount) sets")) · \(Format.weight(kg: volumeKg, unit: unit)) volume")
    }

    // MARK: - Edit Mode Actions
    
    /// Only the author edits. The rows that lead here were shown to everyone, so a reader of a
    /// friend's session from the feed could rewrite its start, duration or notes.
    func enterEditMode(session: WorkoutSessionModel) {
        guard isAuthor(sessionAuthorId: session.authorId) else { return }
        isEditMode = true
    }
        
    /// Done on the workout summary: the workout is over, so the tracker goes with it.
    func onDonePressed() {
        router.dismissEnvironment()
    }

    /// Leaves editing without saving. A pushed screen hides Back while editing, so this is the way
    /// out there; unsaved edits are asked about and then put back as they were.
    func onEndEditingPressed(initialSession: WorkoutSessionModel, session: Binding<WorkoutSessionModel>) {
        guard hasUnsavedChanges(session: initialSession, editedSession: session.wrappedValue) else {
            isEditMode = false
            return
        }
        let restored = lastSavedSession ?? initialSession
        router.showDiscardChangesDialog { [weak self] in
            Task { @MainActor in
                session.wrappedValue = restored
                self?.isEditMode = false
            }
        }
    }

    // MARK: - Timing

    var durationHours: Int = 1
    var durationMinutes: Int = 0

    /// The picker edits a copy. Nothing is written until the sheet's confirm button, and closing it
    /// leaves the session as it was.
    var startDate = Date()

    func onEditStartTimePressed(session: Binding<WorkoutSessionModel>) {
        guard isAuthor(sessionAuthorId: session.wrappedValue.authorId) else { return }
        startDate = session.wrappedValue.dateCreated
        router.showSessionStartTimeView(
            date: Binding(get: { self.startDate }, set: { self.startDate = $0 }),
            onSave: { self.onStartTimeChanged(self.startDate, session: session) }
        )
    }

    func onEditDurationPressed(session: Binding<WorkoutSessionModel>) {
        guard isAuthor(sessionAuthorId: session.wrappedValue.authorId) else { return }
        let current = session.wrappedValue
        let duration = current.activeDuration ?? 0
        durationHours = Int(duration) / 3600
        durationMinutes = (Int(duration) % 3600) / 60
        router.showSessionDurationView(
            hours: Binding(get: { self.durationHours }, set: { self.durationHours = $0 }),
            minutes: Binding(get: { self.durationMinutes }, set: { self.durationMinutes = $0 }),
            onSave: { self.onDurationConfirmed(session: session) }
        )
    }

    /// Both timing edits save from their sheet's confirm button rather than joining the
    /// exercise-editing flow — the user changed one field in a picker and expects it kept.
    func onStartTimeChanged(_ date: Date, session: Binding<WorkoutSessionModel>) {
        session.wrappedValue.updateStart(date)
        persistTimingChange(session.wrappedValue)
    }

    func onDurationConfirmed(session: Binding<WorkoutSessionModel>) {
        let seconds = TimeInterval(durationHours * 3600 + durationMinutes * 60)
        guard seconds > 0 else { return }
        session.wrappedValue.updateDuration(seconds)
        persistTimingChange(session.wrappedValue)
    }

    private func persistTimingChange(_ session: WorkoutSessionModel) {
        Task {
            interactor.trackEvent(event: Event.saveTimingStart)
            do {
                try await interactor.saveWorkoutSession(session)
                interactor.trackEvent(event: Event.saveTimingSuccess)
                lastSavedSession = session
                interactor.playHaptic(option: .success)
            } catch {
                interactor.trackEvent(event: Event.saveTimingFail(error: error))
                interactor.playHaptic(option: .error)
                router.showSimpleAlert(
                    title: String(localized: "Unable to Save Workout"),
                    subtitle: String(localized: "Unable to save the change. Please try again.")
                )
            }
        }
    }

    func saveChanges(initialSession: WorkoutSessionModel, session: Binding<WorkoutSessionModel>) async {
        router.showLoadingModal()
        isSaving = true
        defer {
            router.dismissModal()
            isSaving = false
        }
        
        do {
            // Update dateModified using the model's method
            guard initialSession != session.wrappedValue else {
                isEditMode = false
                return
            }
            session.wrappedValue.updateExercises(session.wrappedValue.exercises)

            interactor.trackEvent(event: Event.saveChangesStart)
            try await interactor.saveWorkoutSession(session.wrappedValue)
            interactor.trackEvent(event: Event.saveChangesSuccess)
            interactor.playHaptic(option: .success)

            // Stays on the screen, which already shows the saved workout. Leaving would return a
            // pushed session to its list, and the summary to the finished tracker behind it.
            lastSavedSession = session.wrappedValue
            isEditMode = false
        } catch {
            interactor.trackEvent(event: Event.saveChangesFail(error: error))
            interactor.playHaptic(option: .error)
            router.showSimpleAlert(
                title: String(localized: "Unable to Save Workout"),
                subtitle: String(localized: "Unable to save changes. Please try again.")
            )
        }
    }
    
    // MARK: - Exercise Updates

    // Edit mode shows the tracker's own exercise rows, so sets are corrected the way they were
    // logged. The rows edit the session through their binding; these cover what they hand back.

    func setSupersetGroupId(session: Binding<WorkoutSessionModel>, _ groupId: String?, forExerciseId exerciseId: String) {
        guard let index = session.wrappedValue.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        session.wrappedValue.exercises[index].supersetGroupId = groupId
    }

    /// An empty note clears it, as in the tracker.
    func updateExerciseNotes(session: Binding<WorkoutSessionModel>, _ notes: String, exerciseId: String) {
        guard let index = session.wrappedValue.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        session.wrappedValue.exercises[index].notes = trimmed.isEmpty ? nil : trimmed
    }

    func updateExercise(session: Binding<WorkoutSessionModel>, at index: Int, with updated: WorkoutExerciseModel) {
        guard session.wrappedValue.exercises.indices.contains(index) else { return }
        
        var updatedExercises = session.wrappedValue.exercises
        updatedExercises[index] = updated
        session.wrappedValue.updateExercises(updatedExercises)
    }
    
    // MARK: - Set Management
    
    /// Adds one more set — which is two rows for an exercise worked a side at a time, so editing a
    /// past session can never leave a left with no right to follow it.
    func addSet(session: Binding<WorkoutSessionModel>, to exerciseId: String) {
        guard let exerciseIndex = session.wrappedValue.exercises.firstIndex(where: { $0.id == exerciseId }),
              let userId = interactor.currentUser?.userId else { return }

        var updatedExercises = session.wrappedValue.exercises
        let existingSets = updatedExercises[exerciseIndex].sets
        // One past the highest index, not one past the count: deleting a set leaves a gap in the
        // numbering, and counting instead of looking handed the new set an index another set
        // already held. Duplicate indices are what last session's figures are matched on.
        var nextIndex = (existingSets.map(\.index).max() ?? 0) + 1
        let sides: [SetSide?] = updatedExercises[exerciseIndex].isPerSide ? SetSide.ordered.map { $0 } : [nil]

        for side in sides {
            // Carry forward the last set on the same side, so a left set copies the left limb's
            // weight rather than the right one's.
            let lastSet = existingSets.last(where: { side == nil || $0.side == side }) ?? existingSets.last
            updatedExercises[exerciseIndex].sets.append(
                WorkoutSetModel(
                    id: UUID().uuidString,
                    authorId: userId,
                    index: nextIndex,
                    reps: lastSet?.reps,
                    weightKg: lastSet?.weightKg,
                    durationSec: lastSet?.durationSec,
                    distanceMeters: lastSet?.distanceMeters,
                    rpe: lastSet?.rpe,
                    side: side,
                    isWarmup: false,
                    // A set added to a finished workout is one the user did and forgot to log.
                    completedAt: Date(),
                    dateCreated: Date()
                )
            )
            // Both halves of a pair keep their own index — they are told apart by `side`, never by
            // sharing a number.
            nextIndex += 1
        }

        session.wrappedValue.updateExercises(updatedExercises)
    }

    /// Deleting half of a left/right pair would leave the other half standing alone, numbering and
    /// counting as a set in its own right, so the pair goes together.
    func deleteSet(session: Binding<WorkoutSessionModel>, _ setId: String, from exerciseId: String) {
        guard let exerciseIndex = session.wrappedValue.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }

        var updatedExercises = session.wrappedValue.exercises
        let removing = Set(updatedExercises[exerciseIndex].sets.pairedSetIds(for: setId))
        guard !removing.isEmpty else { return }

        updatedExercises[exerciseIndex].sets.removeAll { removing.contains($0.id) }

        // Close the gap, or the numbers on screen skip and the next set added collides with one
        // already there. Position gives every remaining row its own index, pairs included.
        for index in updatedExercises[exerciseIndex].sets.indices {
            updatedExercises[exerciseIndex].sets[index].index = index + 1
        }

        session.wrappedValue.updateExercises(updatedExercises)
    }
    
    // MARK: - Exercise Management
    
    func deleteExercise(session: Binding<WorkoutSessionModel>, id: String) {
        
        var updatedExercises = session.wrappedValue.exercises
        updatedExercises.removeAll { $0.id == id }
        
        // Reindex remaining exercises
        for index in updatedExercises.indices {
            updatedExercises[index].index = index + 1
        }
        
        session.wrappedValue.updateExercises(updatedExercises)
    }
    
    func addSelectedExercises(session: Binding<WorkoutSessionModel>) {
        guard !selectedExerciseModels.isEmpty,
              let userId = interactor.currentUser?.userId else {
            return
        }
        
        var updated = session.wrappedValue.exercises
        let startIndex = updated.count
        
        for (offset, template) in selectedExerciseModels.enumerated() {
            let index = startIndex + offset + 1
            let mode = WorkoutSessionModel.trackingMode(for: template.exercise)
            let targetCount = max(template.setTargets.count, 1)
            // An exercise added to a finished session has no sets to read a side off yet, so the
            // exercise itself decides — the same call `WorkoutSessionModel` makes when it builds a
            // session from a template. Without it a single-arm row joins as sideless rows and can
            // never gain a side afterwards.
            let defaultSets = WorkoutSessionModel.defaultSets(
                trackingMode: mode,
                authorId: userId,
                targetCount: targetCount,
                perSide: WorkoutSessionModel.isPerSide(template.exercise)
            )
            let imageName = Constants.exerciseImageName(for: template.exercise.name)
            
            let newExercise = WorkoutExerciseModel(
                id: UUID().uuidString,
                authorId: userId,
                templateId: template.exercise.id,
                name: template.exercise.name,
                trackingMode: mode,
                index: index,
                notes: nil,
                imageName: imageName,
                sets: defaultSets,
                equipmentVariations: template.exercise.equipmentVariations
            )
            updated.append(newExercise)
        }
        
        session.wrappedValue.updateExercises(updated)
        selectedExerciseModels.removeAll()
    }
    
    // MARK: - Unit Preferences
    
    func getUnitPreference(for templateId: String) -> (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit) {
        let preference = interactor.getPreference(templateId: templateId)
        return (weightUnit: preference.weightUnit, distanceUnit: preference.distanceUnit)
    }

    func updateWeightUnit(_ unit: ExerciseWeightUnit, for templateId: String) {
        interactor.setPreference(weightUnit: unit, distanceUnit: getUnitPreference(for: templateId).distanceUnit, for: templateId)
    }

    func updateDistanceUnit(_ unit: ExerciseDistanceUnit, for templateId: String) {
        interactor.setPreference(weightUnit: getUnitPreference(for: templateId).weightUnit, distanceUnit: unit, for: templateId)
    }
    
    // MARK: - Delete Session
    
    func onDeletePressed(session: WorkoutSessionModel) {
        router.showAlert(
            title: String(localized: "Delete Workout?"),
            subtitle: String(localized: "Are you sure you want to delete this workout? This cannot be undone.")) {
                AnyView(
                    HStack {
                        Button(role: .cancel) { }
                        Button(role: .destructive) {
                            self.deleteSession(session: session)
                        }
                    }
                )
            }
    }

    /// Dismisses only once the delete has landed, so a failure can still be shown on this screen.
    func deleteSession(session: WorkoutSessionModel) {
        Task {
            interactor.trackEvent(event: Event.deleteSessionStart)
            do {
                try await interactor.deleteWorkoutSession(id: session.id)
                interactor.trackEvent(event: Event.deleteSessionSuccess)
                if isWorkoutSummary {
                    router.dismissEnvironment()
                } else {
                    router.dismissScreen()
                }
            } catch {
                interactor.trackEvent(event: Event.deleteSessionFail(error: error))
                interactor.playHaptic(option: .error)
                router.showSimpleAlert(title: String(localized: "Unable to Delete Workout"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    func onAddExercisePressed() {
        router.showExercisesPickerView(
            delegate: ExercisesPickerDelegate(
                addedExercises: Binding(
                    get: {
                        self.selectedExerciseModels
                    },
                    set: { newValue in
                        self.selectedExerciseModels = newValue
                    }
                )
            )
        )
    }

    // MARK: - Share Image

    /// First name and avatar of the author only, and no comments. The author may still be loading
    /// when this is tapped, in which case the card goes out without a name rather than waiting.
    func shareCardContent(session: WorkoutSessionModel) -> ShareCardContent {
        ShareCardContent.make(session: session, author: author, history: interactor.workoutSessions(authoredBy: session.authorId))
    }

    func onShareImagePressed(session: WorkoutSessionModel, format: WorkoutShareCardView.Format) {
        let content = shareCardContent(session: session)
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

    // MARK: - Copy Link

    /// The session's public web page, absent where that page would refuse it — including while
    /// the author is still loading, since a private author's link would only 404.
    func webLink(session: WorkoutSessionModel) -> URL? {
        SessionWebLink.url(for: session, author: author)
    }

    func onCopyLinkPressed(_ link: URL, session: WorkoutSessionModel) {
        UIPasteboard.general.url = link
        interactor.playHaptic(option: .success)
        interactor.trackEvent(event: Event.copyLink(sessionId: session.id))
    }

}

extension WorkoutSessionDetailPresenter {
    enum Event: LoggableEvent {
        case onAppear(delegate: WorkoutSessionDetailDelegate)
        case onDisappear(delegate: WorkoutSessionDetailDelegate)
        case loadAuthorFail(error: Error)
        case saveTimingStart
        case saveTimingSuccess
        case saveTimingFail(error: Error)
        case saveChangesStart
        case saveChangesSuccess
        case saveChangesFail(error: Error)
        case deleteSessionStart
        case deleteSessionSuccess
        case deleteSessionFail(error: Error)
        case copyLink(sessionId: String)

        var eventName: String {
            switch self {
            case .onAppear: return "WorkoutSessionDetailView_Appear"
            case .onDisappear: return "WorkoutSessionDetailView_Disappear"
            case .loadAuthorFail: return "WorkoutSessionDetailView_LoadAuthor_Fail"
            case .saveTimingStart: return "WorkoutSessionDetailView_SaveTiming_Start"
            case .saveTimingSuccess: return "WorkoutSessionDetailView_SaveTiming_Success"
            case .saveTimingFail: return "WorkoutSessionDetailView_SaveTiming_Fail"
            case .saveChangesStart: return "WorkoutSessionDetailView_SaveChanges_Start"
            case .saveChangesSuccess: return "WorkoutSessionDetailView_SaveChanges_Success"
            case .saveChangesFail: return "WorkoutSessionDetailView_SaveChanges_Fail"
            case .deleteSessionStart: return "WorkoutSessionDetailView_DeleteSession_Start"
            case .deleteSessionSuccess: return "WorkoutSessionDetailView_DeleteSession_Success"
            case .deleteSessionFail: return "WorkoutSessionDetailView_DeleteSession_Fail"
            case .copyLink: return "WorkoutSessionDetailView_CopyLink"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let delegate), .onDisappear(let delegate):
                return ["session_id": delegate.initialSession.id, "is_workout_summary": delegate.isWorkoutSummary]
            case .loadAuthorFail(error: let error), .saveTimingFail(error: let error), .saveChangesFail(error: let error), .deleteSessionFail(error: let error):
                return error.eventParameters
            case .copyLink(let sessionId): return ["session_id": sessionId]
            default: return nil
            }
        }

        var type: LogType {
            switch self {
            case .saveTimingFail, .saveChangesFail, .deleteSessionFail: return .severe
            case .loadAuthorFail: return .warning
            default: return .analytic
            }
        }
    }
}
