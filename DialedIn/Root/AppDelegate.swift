//
//  AppDelegate.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI
import Firebase
import FirebaseMessaging
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    // Safe: both are set in application(_:didFinishLaunchingWithOptions:) before any use.
    var dependencies: Dependencies!
    var builder: CoreBuilder!

    #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
    /// The Live Activity's way into the app (spec: docs/specs/live-activity.md §7.1).
    ///
    /// Held here because `LiveActivityIntentHandler.current` is weak on purpose, and the app
    /// delegate is the one object that lives exactly as long as the process. A background launch
    /// for an intent runs this method before any `perform()`, so the handler is always in place.
    private var liveActivityIntentHandler: AppLiveActivityIntentHandler?
    #endif

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        var config: BuildConfiguration
        
        #if MOCK
        config = .mock(scenario: .existingSignedIn)
        #elseif DEBUG
        config = .dev
        #else
        config = .prod
        #endif
        
        if Utilities.isUITesting {
            let isSignedIn = ProcessInfo.processInfo.arguments.contains("SIGNED_IN")
            config = .mock(scenario: isSignedIn ? .existingSignedIn : .newAnonymous)
        }
        
        config.configure()
        
        // Must be called AFTER configuring Firebase
        registerForRemotePushNotifications(application: application)

        let dependencies = Dependencies(config: config)
        self.dependencies = dependencies
        self.builder = CoreBuilder(interactor: CoreInteractor(container: dependencies.container))
        registerLiveActivityIntentHandler(container: dependencies.container)
        seedPushPayloadFromLaunchArguments()
        registerAppIntents()
        return true
    }

    /// Siri and Shortcuts reach the app through this interactor (see `AppIntentsBridge`). The
    /// "Start <workout>" phrases list template names, so they are refreshed once the signed-in
    /// user's data has synced.
    private func registerAppIntents() {
        AppIntentsBridge.interactor = builder.interactor
        NotificationCenter.default.addObserver(forName: Constants.remoteDataSyncDidComplete, object: nil, queue: .main) { _ in
            DialedInAppShortcuts.updateAppShortcutParameters()
        }
    }
    
    /// Registered for every configuration, mock included, so the Mock scheme exercises the same
    /// path the device does.
    private func registerLiveActivityIntentHandler(container: DependencyContainer) {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        let handler = AppLiveActivityIntentHandler(
            // Safe: Dependencies registers every one of these for every BuildConfiguration.
            workoutSessionManager: container.resolve(WorkoutSessionManager.self)!,
            hkWorkoutManager: container.resolve(HKWorkoutManager.self)!,
            liveActivityUpdater: container.resolve(LiveActivityManager.self)!,
            workoutSettingsManager: container.resolve(WorkoutSettingsManager.self)!,
            exerciseSettingsManager: container.resolve(ExerciseSettingsManager.self)!,
            exerciseModelManager: container.resolve(ExerciseModelManager.self)!,
            gymProfileManager: container.resolve(GymProfileManager.self)!,
            trainingProgramManager: container.resolve(TrainingProgramManager.self)!,
            userManager: container.resolve(UserManager.self)!,
            streakManager: container.resolve(StreakManager.self),
            stravaManager: container.resolve(StravaManager.self),
            logManager: container.resolve(LogManager.self)!
        )
        liveActivityIntentHandler = handler
        LiveActivityIntentHandler.current = handler
        #endif
    }

    /// `PUSH_PAYLOAD_JSON '{"type":"follow_request"}'` as launch arguments stands in for a push
    /// tapped to launch the app, which the simulator cannot deliver on its own.
    private func seedPushPayloadFromLaunchArguments() {
        #if MOCK || DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let index = arguments.firstIndex(of: "PUSH_PAYLOAD_JSON"),
            arguments.indices.contains(index + 1),
            let data = arguments[index + 1].data(using: .utf8),
            let payload = try? JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any]
        else { return }
        storePendingDeepLink(DeepLink(pushUserInfo: payload))
        #endif
    }

    private func registerForRemotePushNotifications(application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        #if !MOCK
        // Only need to set Firebase Messaging if Firebase is configured
        Messaging.messaging().delegate = self
        #endif
        application.registerForRemoteNotifications()
    }

}

/// Firbase Cloud Messaging Docs: https://firebase.google.com/docs/cloud-messaging/ios/client
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        #if DEBUG
        print("🚨 didFailToRegisterForRemoteNotificationsWithError: \(error.localizedDescription)")
        #endif
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // With the app in front the tracker plays its own rest-over sound and haptic; a banner and
        // a second sound on top of them would announce the same moment twice.
        guard notification.request.identifier != RestOverNotification.id else {
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        // FCM puts the message's `data` keys at the top level of userInfo, beside `aps` — reading
        // only `aps` meant no tap ever carried a destination. Parsed here because userInfo is not
        // Sendable; `DeepLink` is.
        let deepLink = DeepLink(pushUserInfo: response.notification.request.content.userInfo)
        await storePendingDeepLink(deepLink)
    }

    /// Parks the destination on `PushManager` and tells a tab bar already on screen to take it. On a
    /// cold start nothing is listening yet; `logIn` and the tab bar's appear pick it up instead.
    private func storePendingDeepLink(_ deepLink: DeepLink?) {
        guard let deepLink else { return }
        dependencies?.container.resolve(PushManager.self)?.storePendingDeepLink(deepLink)
        NotificationCenter.default.post(name: .pushNotification, object: nil)
    }
}

extension AppDelegate: MessagingDelegate {
    
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        NotificationCenter.default.postFCMToken(token: fcmToken ?? "")
    }
}

enum MockScenario {
    case newAnonymous
    case existingSignedOut
    case existingSignedIn
}

enum BuildConfiguration {
    case mock(scenario: MockScenario), dev, prod
    
    func configure() {
        switch self {
        case .mock:
            break
        case .dev:
            // Deliberate launch crash: the app cannot run without its Firebase plist (see CLAUDE.md First-Time Setup).
            let plist = Bundle.main.path(forResource: "GoogleService-Info-Dev", ofType: "plist")!
            let options = FirebaseOptions(contentsOfFile: plist)!
            #if targetEnvironment(simulator)
            AppCheck.setAppCheckProviderFactory(DebugAppCheckProviderFactory())
            #else
            let providerFactory = MyAppCheckProviderFactory()
            AppCheck.setAppCheckProviderFactory(providerFactory)
            #endif
            FirebaseApp.configure(options: options)
            Self.configureGoogleSignInAppCheck(apiKey: options.apiKey)
            Analytics.setAnalyticsCollectionEnabled(true)
            #if DEBUG
            if NetworkMonitor.isOfflineTesting {
                Self.pointFirebaseAtUnreachableHost()
            }
            #endif
            
        case .prod:
            // Deliberate launch crash: the app cannot run without its Firebase plist (see CLAUDE.md First-Time Setup).
            let plist = Bundle.main.path(forResource: "GoogleService-Info-Prod", ofType: "plist")!
            let options = FirebaseOptions(contentsOfFile: plist)!
            let providerFactory = MyAppCheckProviderFactory()
            AppCheck.setAppCheckProviderFactory(providerFactory)
            FirebaseApp.configure(options: options)
            Self.configureGoogleSignInAppCheck(apiKey: options.apiKey)
            Analytics.setAnalyticsCollectionEnabled(true)
        }
        // Started now so it has a path by the time anything asks.
        _ = NetworkMonitor.shared
    }

    /// Google Sign-In 8 attaches its own App Check token to the OAuth request, separate from
    /// Firebase's. The OAuth client enforces it, so without this call Google answers
    /// "We cannot verify the authenticity of this app … Token failed" (Error 400: invalid_request).
    /// The simulator uses the same debug token as Firebase App Check, registered in the console.
    /// The token exchange is addressed to `oauthClients/{GIDClientID}`, read from Info.plist; the
    /// per-configuration `INFOPLIST_KEY_GIDClientID` build setting supplies it.
    private static func configureGoogleSignInAppCheck(apiKey: String?) {
        #if targetEnvironment(simulator)
        guard let apiKey else { return }
        GIDSignIn.sharedInstance.configureDebugProvider(withAPIKey: apiKey) { error in
            if let error { print("GIDSignIn App Check debug configure failed: \(error)") }
        }
        #else
        GIDSignIn.sharedInstance.configure { error in
            if let error { print("GIDSignIn App Check configure failed: \(error)") }
        }
        #endif
    }

    #if DEBUG
    /// `OFFLINE_TESTING` on the Development scheme: Firestore, Functions and Storage talk to an
    /// address that never answers, which is how a device with no signal behaves — writes queue,
    /// reads fall back to the cache, and anything awaiting the server waits. Must run before the
    /// first use of each, which is why it is here and not in `Dependencies`.
    private static func pointFirebaseAtUnreachableHost() {
        let host = "10.255.255.1"
        Firestore.firestore().useEmulator(withHost: host, port: 8080)
        Functions.functions(region: "us-central1").useEmulator(withHost: host, port: 5001)
        Storage.storage().useEmulator(withHost: host, port: 9199)
    }
    #endif
}
