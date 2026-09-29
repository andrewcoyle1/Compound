//
//  CreateExercisePresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

@Observable
@MainActor
class CreateExercisePresenter {
    private let interactor: CreateExerciseInteractor
    private let router: CreateExerciseRouter

    var exerciseName: String?

    var trackableMetricA: TrackableExerciseMetric?
    var trackableMetricB: TrackableExerciseMetric?

    var exerciseType: ExerciseType?
    
    var laterality: Laterality?
    
    var canSave: Bool {
        let trimmedName = exerciseName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasName = !(trimmedName?.isEmpty ?? true)
        let hasMetric = trackableMetricA != nil || trackableMetricB != nil
        return hasName && hasMetric
    }
    
    init(
        interactor: CreateExerciseInteractor,
        router: CreateExerciseRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func trackableMetricPressed(navigationTitle: String, metric: Binding<TrackableExerciseMetric?>) {
        pickItem(navigationTitle: navigationTitle, item: metric, canDelete: true, detents: nil)
    }
    
    func exerciseTypePressed(navigationTitle: String, type: Binding<ExerciseType?>) {
        pickItem(navigationTitle: navigationTitle, item: type, canDelete: false, detents: .medium)
    }
    
    func lateralityPressed(navigationTitle: String, item: Binding<Laterality?>) {
        pickItem(navigationTitle: navigationTitle, item: item, canDelete: false, detents: .medium)
    }
    
    private func pickItem<Item: PickableItem>(navigationTitle: String, item: Binding<Item?>, canDelete: Bool, detents: PresentationDetentTransformable?) {
        router.showEnumPickerView(
            delegate: EnumPickerDelegate<Item>(
                navigationTitle: navigationTitle,
                chosenItem: item,
                canDelete: canDelete
            ),
            detentsInput: detents
        )
    }
    
    func onNextPressed() {
        let trimmedName = exerciseName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name = trimmedName, !name.isEmpty else { return }

        if trackableMetricA == nil, let onlyMetric = trackableMetricB {
            trackableMetricA = onlyMetric
            trackableMetricB = nil
        }

        guard let trackableMetricA else { return }
        router.showMuscleGroupPickerView(
            delegate: MuscleGroupPickerDelegate(
                name: name,
                trackableMetricA: trackableMetricA,
                trackableMetricB: trackableMetricB,
                exerciseType: exerciseType,
                laterality: laterality
            )
        )
    }

    /// Anything typed or picked. Close used to drop it without asking.
    var hasUnsavedChanges: Bool {
        let hasName = !(exerciseName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return hasName || trackableMetricA != nil || trackableMetricB != nil || exerciseType != nil || laterality != nil
    }

    func onCancelPressed() {
        guard hasUnsavedChanges else {
            router.dismissScreen()
            return
        }
        router.showDiscardChangesDialog { [weak self] in
            Task { @MainActor in self?.router.dismissScreen() }
        }
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear:     return "CreateExerciseView_Appear"
            case .onDisappear:  return "CreateExerciseView_Disappear"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }
}
