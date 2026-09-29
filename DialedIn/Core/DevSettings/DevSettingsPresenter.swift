//
//  DevSettingsPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 20/10/2025.
//

import SwiftUI

@Observable
@MainActor
class DevSettingsPresenter {

    private let interactor: DevSettingsInteractor
    private let router: DevSettingsRouter
    
    private(set) var isReseeding = false
    private(set) var reseedingMessage = ""
    private(set) var fetchedSession: WorkoutSessionModel?
    private(set) var isFetchingSession = false
    private(set) var fetchError: String?

    var testSessionId = ""
    
    var isInNotificationsABTest: Bool = false
    var paywallTest: PaywallTestOption = .default

#if DEV || MOCK
    /// Mirror of ``PremiumOverride/isEnabled`` for the "Simulate Premium" toggle. Guarded the
    /// same way the override itself is, so no part of the escape hatch reaches a release build.
    var simulatePremium: Bool = false

    func loadPremiumOverride() {
        simulatePremium = PremiumOverride.isEnabled
    }

    func handleSimulatePremiumChange(oldValue: Bool, newValue: Bool) {
        PremiumOverride.isEnabled = newValue
    }
#endif

    var workoutSessions: [WorkoutSessionModel] {
        interactor.workoutSessions
    }
    
    var allExercises: [ExerciseModel] {
        interactor.allExercises
    }
    
    var activeSession: WorkoutSessionModel? {
        interactor.activeSession
    }
    
    var userWorkoutTemplates: [WorkoutTemplateModel] {
        interactor.userWorkoutTemplates
    }
    
    var systemWorkoutTemplates: [WorkoutTemplateModel] {
        interactor.systemWorkoutTemplates
    }
    
    var allWorkoutTemplates: [WorkoutTemplateModel] {
        interactor.allWorkoutTemplates
    }
    
    init(
        interactor: DevSettingsInteractor,
        router: DevSettingsRouter
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

    func authParams() -> [(key: String, value: Any)] {
        interactor.auth?.eventParameters.asAlphabeticalArray ?? []
    }
    
    func userParams() -> [(key: String, value: Any)] {
        interactor.currentUser?.eventParameters.asAlphabeticalArray ?? []
    }
    
    func loadABTests() {
        isInNotificationsABTest = interactor.activeTests.notificationsTest
        paywallTest = interactor.activeTests.paywallTest
    }

    func handleNotificationTestChange(oldValue: Bool, newValue: Bool) {
        updateTest(property: &isInNotificationsABTest, newValue: newValue, savedValue: interactor.activeTests.notificationsTest) { tests in
            tests.update(notificationsTest: newValue)
        }
    }
    
    func handlePaywallOptionChange(oldValue: PaywallTestOption, newValue: PaywallTestOption) {
        updateTest(
            property: &paywallTest,
            newValue: newValue,
            savedValue: interactor.activeTests.paywallTest,
            updateAction: { tests in
                tests.update(paywallTest: newValue)
            }
        )
    }

    private func updateTest<Value: Equatable>(
        property: inout Value,
        newValue: Value,
        savedValue: Value,
        updateAction: (inout ActiveABTests) -> Void
    ) {
        if newValue != savedValue {
            do {
                var tests = interactor.activeTests
                updateAction(&tests)
                try interactor.override(updatedTests: tests)
            } catch {
                property = savedValue
                router.showAlert(error: error)
            }
        }
    }
    
    func deviceParams() -> [(key: String, value: Any)] {
        Utilities.eventParameters.asAlphabeticalArray
    }
                    
    func resetExerciseSeeding() async {
        isReseeding = true
        reseedingMessage = "Resetting exercises..."

        UserDefaults.standard.removeObject(forKey: "hasSeededPrebuiltExercisesV2")
        UserDefaults.standard.removeObject(forKey: "prebuiltExercisesSeedingVersionV2")
        
        reseedingMessage = "Complete! Restart app to reseed."
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        isReseeding = false
        reseedingMessage = ""
    }
    
    func resetWorkoutSeeding() async {
        isReseeding = true
        reseedingMessage = "Resetting workouts..."
        
        UserDefaults.standard.removeObject(forKey: "hasSeededPrebuiltWorkouts")
        UserDefaults.standard.removeObject(forKey: "prebuiltWorkoutsSeedingVersion")
        
        reseedingMessage = "Complete! Restart app to reseed."
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        isReseeding = false
        reseedingMessage = ""
    }
    
    func resetProgramSeeding() async {
        isReseeding = true
        reseedingMessage = "Resetting programs..."

        UserDefaults.standard.removeObject(forKey: TrainingProgramManager.hasSeededKey)
        UserDefaults.standard.removeObject(forKey: TrainingProgramManager.seedingVersionKey)

        reseedingMessage = "Complete! Restart app to reseed."

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        isReseeding = false
        reseedingMessage = ""
    }

    func resetAllSeeding() async {
        isReseeding = true
        reseedingMessage = "Resetting all seeding..."

        UserDefaults.standard.removeObject(forKey: "hasSeededPrebuiltExercisesV2")
        UserDefaults.standard.removeObject(forKey: "prebuiltExercisesSeedingVersionV2")
        UserDefaults.standard.removeObject(forKey: "hasSeededPrebuiltWorkouts")
        UserDefaults.standard.removeObject(forKey: "prebuiltWorkoutsSeedingVersion")
        UserDefaults.standard.removeObject(forKey: TrainingProgramManager.hasSeededKey)
        UserDefaults.standard.removeObject(forKey: TrainingProgramManager.seedingVersionKey)
        
        reseedingMessage = "Complete! Restart app to reseed."
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        isReseeding = false
        reseedingMessage = ""
    }
        
    func fetchSessionFromFirebase() async {
        isFetchingSession = true
        fetchError = nil
        fetchedSession = nil
        
        do {
            let session = try await interactor.getWorkoutSession(id: testSessionId)
            await MainActor.run {
                fetchedSession = session
                isFetchingSession = false
            }
        } catch {
            await MainActor.run {
                fetchError = error.localizedDescription
                isFetchingSession = false
            }
        }
    }
    
    func onForceFreshAnonUser() {
        defer {
            router.dismissScreen()
        }
        interactor.trackEvent(event: Event.forceSignOutStart)
        Task {
            do {
                try await interactor.signOut()
                interactor.trackEvent(event: Event.forceSignOutSuccess)
                try await Task.sleep(for: .seconds(1))
                router.switchToOnboardingModule()

            } catch {
                interactor.trackEvent(event: Event.forceSignOutFail(error: error))
                router.showAlert(error: error)
            }
        }
    }
        
    func onDismissPressed() {
        router.dismissScreen()
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case forceSignOutStart
        case forceSignOutSuccess
        case forceSignOutFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:             return "DevSettingsView_Appear"
            case .onDisappear:          return "DevSettingsView_Disappear"
            case .forceSignOutStart:    return "DevSettingsView_ForceSignOut_Start"
            case .forceSignOutSuccess:  return "DevSettingsView_ForceSignOut_Success"
            case .forceSignOutFail:     return "DevSettingsView_ForceSignOut_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .forceSignOutFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .forceSignOutFail:
                return .severe
            default:
                return .analytic
                
            }
        }
    }

    // MARK: - Share Card

    func onSaveShareCardsPressed() {
        let content = ShareCardContent.mock()
        Task {
            for format in WorkoutShareCardView.Format.allCases {
                if let image = await ShareCardRenderer.renderCard(content, format: format) {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }
            }
            router.showSimpleAlert(title: "Share cards saved to Photos", subtitle: nil)
        }
    }
}
