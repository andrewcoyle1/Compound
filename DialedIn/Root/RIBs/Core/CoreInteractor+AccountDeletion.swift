//
//  CoreInteractor+AccountDeletion.swift
//  DialedIn
//

import Foundation

extension CoreInteractor {

    /// Every listener except the user's own — the one list both `signOut()` and `deleteAccount()`
    /// use, so the two cannot drift. `signOut()` stops the user's listener itself first;
    /// `deleteCurrentUser` stops it during deletion. Runs before the user document is deleted:
    /// the `onUserDeleted` Cloud Function then deletes every subcollection, and a listener still
    /// attached would log a permission error for each one once Auth is gone.
    func stopListeningBeforeAccountDeletion() {
        stepsManager.signOut()
        workoutTemplateManager.signOut()
        workoutSessionManager.signOut()
        gymProfileManager.signOut()
        trainingProgramManager.signOut()
        exerciseModelManager.signOut()
        workoutSettingsManager.signOut()
        foodLogSettingsManager.signOut()
        nutritionStrategySettingsManager.signOut()
        nutritionStrategyManager.signOut()
        analyticsSettingsManager.signOut()
        shortcutSettingsManager.signOut()
        exerciseSettingsManager.signOut()
        recipeTemplateManager.signOut()
        foodManager.signOut()
        nutritionManager.signOut()
        mealLogManager.signOut()
        bodyMeasurementsManager.signOut()
        goalManager.signOut()
        streakManager.logOut()
        activityNotificationManager.stopListening()
        progressPhotoManager.stopListening()
    }
}
