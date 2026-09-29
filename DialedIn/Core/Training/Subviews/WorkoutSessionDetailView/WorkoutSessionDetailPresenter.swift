//
//  WorkoutSessionDetailPresenter.swift
//  DialedIn
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
    private(set) var exerciseUnitPreferences: [String: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)] = [:]
        
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
        
    func hasUnsavedChanges(session: WorkoutSessionModel, editedSession: WorkoutSessionModel) -> Bool {
        editedSession != session
    }
    
    init(
        interactor: WorkoutSessionDetailInteractor,
        router: WorkoutSessionDetailRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func loadAuthor(for session: WorkoutSessionModel) async {
        let authorId = session.authorId
        if let currentUser = interactor.currentUser, currentUser.userId == authorId {
            author = currentUser
            return
        }
        // An author who cannot be read stays unknown: no header is better than someone else's name.
        author = try? await interactor.getUser(userId: authorId)
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
    
    func volumeFormatted(session: WorkoutSessionModel) -> String {
        let volume = totalVolume(session: session)
        if volume > 0 {
            return String(format: "%.0f kg", volume)
        } else {
            return "—"
        }
    }
    
    // MARK: - Edit Mode Actions
    
    func enterEditMode(session: WorkoutSessionModel) {
        isEditMode = true
        loadUnitPreferences(for: session)
    }
        
    func showDiscardChangesAlert(session: WorkoutSessionModel) {
        router.showAlert(
            title: String(localized: "Discard changes?"),
            subtitle: String(localized: "You have unsaved changes. This will discard them."),
            buttons: {
                AnyView(
                    VStack {
                        Button("Discard Changes", role: .destructive) {
                            self.onDismissPressed()
                        }
                        Button("Keep Editing", role: .cancel) {

                        }
                    }
                )
            }
        )
    }
    
    func onDismissPressed() {
        self.dismissScreen()
    }

    private func dismissScreen() {
        router.dismissScreen()
    }

    // MARK: - Timing

    /// Presents the start-time picker.
    var isEditingStartTime: Bool = false
    /// Presents the duration picker.
    var isEditingDuration: Bool = false
    var durationHours: Int = 1
    var durationMinutes: Int = 0

    func onEditStartTimePressed() {
        isEditingStartTime = true
    }

    func onEditDurationPressed(session: WorkoutSessionModel) {
        let duration = session.endedAt?.timeIntervalSince(session.dateCreated) ?? 0
        durationHours = Int(duration) / 3600
        durationMinutes = (Int(duration) % 3600) / 60
        isEditingDuration = true
    }

    /// Both timing edits save straight away rather than joining the exercise-editing flow — the
    /// user changed one field in a picker and expects it kept.
    func onStartTimeChanged(_ date: Date, session: Binding<WorkoutSessionModel>) {
        session.wrappedValue.updateStart(date)
        persistTimingChange(session.wrappedValue)
    }

    func onDurationConfirmed(session: Binding<WorkoutSessionModel>) {
        let seconds = TimeInterval(durationHours * 3600 + durationMinutes * 60)
        isEditingDuration = false
        guard seconds > 0 else { return }
        session.wrappedValue.updateDuration(seconds)
        persistTimingChange(session.wrappedValue)
    }

    private func persistTimingChange(_ session: WorkoutSessionModel) {
        Task {
            do {
                try await interactor.saveWorkoutSession(session)
            } catch {
                router.showSimpleAlert(
                    title: String(localized: "Save Failed"),
                    subtitle: "Unable to save the change. Please try again."
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
                dismissScreen()
                return
            }
            session.wrappedValue.updateExercises(session.wrappedValue.exercises)
            
            try await interactor.saveWorkoutSession(session.wrappedValue)
            
            isEditMode = false
            
            // Dismiss to refresh parent view
            dismissScreen()
        } catch {
            router.showSimpleAlert(
                title: String(localized: "Save Failed"),
                subtitle: "Unable to save changes. Please try again."
            )
        }
    }
    
    // MARK: - Exercise Updates
    
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
    
    func loadUnitPreferences(for session: WorkoutSessionModel) {
        exerciseUnitPreferences.removeAll(keepingCapacity: true)
        
        for exercise in session.exercises {
            let preference = interactor.getPreference(templateId: exercise.templateId)
            exerciseUnitPreferences[exercise.templateId] = (
                weightUnit: preference.weightUnit,
                distanceUnit: preference.distanceUnit
            )
        }
    }
    
    func getUnitPreference(for templateId: String) -> (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit) {
        if let cached = exerciseUnitPreferences[templateId] {
            return cached
        }
        let preference = interactor.getPreference(templateId: templateId)
        let result = (weightUnit: preference.weightUnit, distanceUnit: preference.distanceUnit)
        exerciseUnitPreferences[templateId] = result
        return result
    }
    
    func updateWeightUnit(_ unit: ExerciseWeightUnit, for templateId: String) {
        var current = getUnitPreference(for: templateId)
        current.weightUnit = unit
        exerciseUnitPreferences[templateId] = current
        interactor.setPreference(weightUnit: unit, distanceUnit: current.distanceUnit, for: templateId)
    }
    
    func updateDistanceUnit(_ unit: ExerciseDistanceUnit, for templateId: String) {
        var current = getUnitPreference(for: templateId)
        current.distanceUnit = unit
        exerciseUnitPreferences[templateId] = current
        interactor.setPreference(weightUnit: current.weightUnit, distanceUnit: unit, for: templateId)
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
            do {
                try await interactor.deleteWorkoutSession(id: session.id)
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.deleteSessionFail(error: error))
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

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif
}

extension WorkoutSessionDetailPresenter {
    enum Event: LoggableEvent {
        case deleteSessionFail(error: Error)
        case copyLink(sessionId: String)

        var eventName: String {
            switch self {
            case .deleteSessionFail: return "WorkoutSessionDetailView_DeleteSession_Fail"
            case .copyLink: return "WorkoutSessionDetailView_CopyLink"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .deleteSessionFail(error: let error): return error.eventParameters
            case .copyLink(let sessionId): return ["session_id": sessionId]
            }
        }

        var type: LogType {
            switch self {
            case .deleteSessionFail: return .severe
            case .copyLink: return .analytic
            }
        }
    }
}
