//
//  Constants.swift
//  DialedIn
//
//  Created by Andrew Coyle on 13/08/2025.
//

import Foundation

struct Constants {
    
//    static let randomImage = "https://picsum.photos/600/600"
    static let randomImage = "SplashScreen"
    /// The address behind Profile's "Support". Was a bare literal at its one call site.
    static let supportEmail = "andrewcoyle.1@outlook.com"

    // ⚠️ PLACEHOLDERS. All four point at apple.com. They are surfaced through `LegalDocument`,
    // which is what the app links to — replace these with the real published documents before
    // release.
    static let termsofServiceURL = "https://www.apple.com"
    static let privacyPolicyURL = "https://www.apple.com"
    static let healthDisclaimerURL = "https://www.apple.com"
    static let consumerHealthPrivacyURL = "https://www.apple.com"
    
    static let onboardingModuleId = "onboarding"
    static let tabBarModuleId = "tabbar"

    static var mixpanelDistinctId: String? {
        #if MOCK
        return nil
        #else
        return MixpanelService.distinctId
        #endif
    }
    
    static var firebaseAnalyticsAppInstanceID: String? {
        #if MOCK
        return nil
        #else
        return FirebaseAnalyticsService.appInstanceID
        #endif
    }
    
    @MainActor
    static var firebaseAppClientId: String? {
        #if MOCK
        return nil
        #else
        return FirebaseAuthService.clientId
        #endif
    }

    // App Group identifier for sharing data between app and widget extension
    static let appGroupIdentifier = "group.com.dialedin.app"
    
    /// Posted when remote data sync completes (e.g. on app foreground). Listen to refresh active training program.
    static let remoteDataSyncDidComplete = Notification.Name("DialedIn.RemoteDataSyncDidComplete")

    /// Posted when a rest timer runs out of its own accord. Cancelling a rest does not post it —
    /// the user who cancelled a rest already knows it is over, and does not need telling.
    static let workoutRestDidComplete = Notification.Name("DialedIn.WorkoutRestDidComplete")

    /// Posted by a screen that needs the tab bar to select a different tab. `TabBarView` is the only
    /// place in the app that can change tabs, and a screen inside one has no route to it — going via
    /// the `compound://` scheme would work but raises the system's "Open in Compound?" prompt for
    /// what is in-app navigation. `userInfo` carries `tab` as a `DeepLink.Tab` raw value.
    static let selectTab = Notification.Name("DialedIn.SelectTab")

    /// Posted after a push tap has selected the Dashboard, asking it to open one workout session.
    /// `userInfo` has the push's own keys — `session_id`, `session_author_id` and `type` — so
    /// `DeepLink(pushUserInfo:)` reads it back. See `DeepLink.post()`.
    static let openWorkoutSession = Notification.Name("DialedIn.OpenWorkoutSession")

    /// Posted after a follow-request push tap has selected the Dashboard, asking it to open the
    /// notifications screen. See `DeepLink.post()`.
    static let openNotifications = Notification.Name("DialedIn.OpenNotifications")

    /// Posted after a `compound://join/<code>` link has selected the Dashboard, asking it to accept
    /// the invite. `userInfo` carries `code`. See `DeepLink.post()`.
    static let acceptInvite = Notification.Name("DialedIn.AcceptInvite")
    
    /// Map exercise template names to bundled asset names for Live Activity
    /// Returns nil for exercises without bundled images
    static func exerciseImageName(for exerciseName: String) -> String? {
        let normalized = exerciseName
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Constants.exerciseImageMap[normalized]
    }

    private static let exerciseImageMap: [String: String] = [
        "barbell bench press": "BarbellBenchPress",
        "barbell incline bench press": "BarbellInclineBenchPress",
        "barbell romanian deadlift": "Barbell_RomanianDeadlift",
        "barbell squat": "BarbellSquat",
        "barbell back squat": "BarbellSquat",
        "barbell sumo deadlift": "BarbellSumoDeadlift",
        "bulgarian split squat": "BulgarianSplitSquat",
        "dumbbell bulgarian split squat": "BulgarianSplitSquat",
        "cable bicep curl (straight bar)": "CableBicepCurl_StraightBar",
        "cable biceps curl (straight bar)": "CableBicepCurl_StraightBar",
        "cable pushdown (straight bar)": "CablePushdown_StraightBar",
        "cable tricep pushdown (straight bar)": "CablePushdown_StraightBar",
        "calf press on leg press": "CalfPressOnLegPress",
        "seated calf press": "CalfPressOnLegPress",
        "chest dip": "ChestDip",
        "dips": "ChestDip",
        "dumbbell incline fly": "Dumbbell_InclineFlyChest",
        "dumbbell incline chest fly": "Dumbbell_InclineFlyChest",
        "dumbbell bench press": "DumbbellBenchPress",
        "dumbbell seated shoulder press": "DumbbellSeatedShoulderPress",
        "ez barbell preacher curl": "EZBarbell_PreacherCurl",
        "preacher curl": "EZBarbell_PreacherCurl",
        "hack squat": "HackSquat",
        "lat prayer (straight bar)": "LatPrayer_StraightBar",
        "lat pulldown (straight bar)": "LatPrayer_StraightBar",
        "lying leg curl": "LyingLegCurl",
        "leg curl": "LyingLegCurl",
        "overhead extension (straight bar)": "OverheadExtensionStraightBar",
        "cable overhead tricep extension (straight bar)": "OverheadExtensionStraightBar",
        "reverse fly": "ReverseFly",
        "reverse pec deck fly": "ReverseFly",
        "seated leg extension": "SeatedLegExtension",
        "leg extension": "SeatedLegExtension",
        "seated row": "SeatedRow",
        "cable seated row": "SeatedRow",
        "machine seated row": "SeatedRow",
        "single arm row": "SingleArmRow",
        "dumbbell single arm row": "SingleArmRow",
        "one arm row": "SingleArmRow",
        "standing lateral raise (cable)": "StandingLatRaise_Cable",
        "cable lateral raise": "StandingLatRaise_Cable",
        "t-bar row": "TBarRow",
        "t bar row": "TBarRow",
        "cable neutral grip lat pulldown": "CableNeutralGripLatPulldown",
        "neutral grip lat pulldown": "CableNeutralGripLatPulldown",
        "cable overhead triceps extension": "CableOverheadTricepsExtension",
        "cable overhead tricep extension": "CableOverheadTricepsExtension",
        "cable standing supinated face pull": "CableStandingSupinatedFacePull",
        "face pull (supinated)": "CableStandingSupinatedFacePull",
        "cable face pull": "CableStandingSupinatedFacePull",
        "lever hip thrust": "LeverHipThrust",
        "machine hip thrust": "LeverHipThrust",
        "lever incline hammer chest press": "LeverInclineHammerChestPress",
        "incline hammer press": "LeverInclineHammerChestPress",
        "lever pec deck fly (chest)": "LeverPecDeckFlyChest",
        "pec deck": "LeverPecDeckFlyChest",
        "lever pendulum squat": "LeverPendulumSquat",
        "pendulum squat": "LeverPendulumSquat",
        "weighted hammer grip pull-up on dip": "WeightedHammerGripPullUpOnDip",
        "neutral grip pull-up": "WeightedHammerGripPullUpOnDip",
        "hammer grip chin-up": "WeightedHammerGripPullUpOnDip"
    ]
}
