import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:ab_test_repository/ab_test_repository.dart';
import 'package:ai_repository/ai_repository.dart';
import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/app/device_store_migration.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/notifications/notifications.dart';
import 'package:compound/sharing/session_web_link.dart';
import 'package:compound_models/compound_models.dart' show logWriteError;
import 'package:connectivity_repository/connectivity_repository.dart';
import 'package:device_store/device_store.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:food_repository/food_repository.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:health_repository/health_repository.dart';
import 'package:http/http.dart' as http;
import 'package:image_repository/image_repository.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:social_repository/social_repository.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// What differs between the two Firebase flavors, development and
/// production (Swift's `.dev` and `.prod` arms of `Dependencies`).
class FirebaseFlavor {
  /// The flavor's choices.
  const new({
    required this.options,
    required this.appleAppCheck,
    required this.androidAppCheck,
    required this.logToConsole,
    required this.mixpanelToken,
    required this.mixpanelBuildConfiguration,
    required this.stravaClientId,
    required this.revenueCatKey,
    required this.bundleId,
    required this.abTests,
    required this.sessionWebLinkBase,
  });

  /// The project's options, from the flavor's gitignored
  /// `firebase_options_<flavor>.dart`.
  final FirebaseOptions options;

  /// The App Check providers.
  final AppleAppCheckProvider appleAppCheck;
  final AndroidAppCheckProvider androidAppCheck;

  /// Whether analytics events are also printed to the device log, with
  /// their parameters (names and emails among them).
  final bool logToConsole;

  /// Mixpanel's project token, off when empty, and the
  /// `build_configuration` super property Swift sets.
  final String mixpanelToken;
  final String mixpanelBuildConfiguration;

  /// Strava's client id. Strava shows as unavailable when it's empty.
  final String stravaClientId;

  /// The running platform's RevenueCat public SDK key. When it is empty
  /// nothing reaches RevenueCat and the premium fake is used instead, which
  /// production must never do.
  final String revenueCatKey;

  /// The flavor's bundle id (iOS) and package name (Android), the same
  /// here, which Health reports as the source of what this app wrote.
  final String bundleId;

  /// The A/B test assignments, given the device's store.
  final FutureOr<AbTestRepository> Function(DeviceStore) abTests;

  /// Workouts' web pages: the sessionPage function behind the project's
  /// Hosting rewrite (Swift's `SessionWebLink.baseURL`).
  final String sessionWebLinkBase;
}

/// Starts Firebase for [flavor] and builds the app on it.
Future<App> firebaseApp(FirebaseFlavor flavor) async {
  final options = flavor.options;
  await Firebase.initializeApp(options: options);
  await FirebaseAppCheck.instance.activate(
    providerAndroid: flavor.androidAppCheck,
    providerApple: flavor.appleAppCheck,
  );
  final crashlytics = FirebaseCrashlytics.instance;
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(crashlytics.recordError(error, stack, fatal: true));
    return true;
  };
  final analyticsRepository = AnalyticsRepository(
    services: [
      if (flavor.logToConsole) const ConsoleService(),
      FirebaseAnalyticsService(analytics: FirebaseAnalytics.instance),
      CrashlyticsService(crashlytics: crashlytics),
      if (flavor.mixpanelToken.isNotEmpty)
        await MixpanelService.init(
          token: flavor.mixpanelToken,
          buildConfiguration: flavor.mixpanelBuildConfiguration,
        ),
    ],
  );
  // A write the server refuses after Firestore applied it locally (the
  // repositories never wait for the server): logged, and a severe event,
  // which Crashlytics records as a non-fatal error.
  void onWriteError(String path, Object error, StackTrace stackTrace) {
    logWriteError(path, error, stackTrace);
    analyticsRepository.trackEvent(
      AnalyticsEvent(
        'Firestore_Write_Fail',
        parameters: {'path': path, 'error_description': '$error'},
        type: LogType.severe,
      ),
    );
  }

  final userRepository = FirestoreUserRepository(
    firestore: FirebaseFirestore.instance,
    onWriteError: onWriteError,
  );
  // Before the app: a tap that launched it is picked up here and held
  // until someone is signed in.
  final notificationsRepository = FirebaseNotificationsRepository(
    messaging: FirebaseMessaging.instance,
    localNotifications: FlutterLocalNotificationsPlugin(),
    userRepository: userRepository,
    copy: AppNotificationCopy(),
    onError: (error, stackTrace) =>
        unawaited(crashlytics.recordError(error, stackTrace)),
  );
  await notificationsRepository.initialize();
  final liveActivityRepository = MethodChannelLiveActivityRepository(
    copy: AppNotificationCopy(),
    onError: (error, stackTrace) =>
        unawaited(crashlytics.recordError(error, stackTrace)),
  );
  await liveActivityRepository.initialize();

  // The workout under way, kept on the device between launches.
  final support = await getApplicationSupportDirectory();
  // Small values kept on the device, as Swift's `UserDefaults`.
  final deviceStore = await SharedPreferencesDeviceStore.create();
  migrateDeviceFiles(deviceStore, support);
  final workoutSessionRepository = FirestoreWorkoutSessionRepository(
    firestore: FirebaseFirestore.instance,
    onWriteError: onWriteError,
  );
  final nutritionRepository = FirestoreNutritionRepository(
    firestore: FirebaseFirestore.instance,
    onWriteError: onWriteError,
  );
  final bodyRepository = FirestoreBodyRepository(
    firestore: FirebaseFirestore.instance,
    onWriteError: onWriteError,
  );
  final trainingLibraryRepository = FirestoreTrainingLibraryRepository(
    firestore: FirebaseFirestore.instance,
    onWriteError: onWriteError,
  );
  final stravaClientId = flavor.stravaClientId;
  if (stravaClientId.isEmpty) {
    developer.log(
      'The Strava client id is not set (dart_defines.json): Strava is '
      'unavailable in this build',
      name: 'strava',
    );
  }
  return App(
    appVersion: await AppVersion.load(),
    connectivityRepository: ConnectivityRepository(),
    healthRepository: HealthRepository(
      platform: HealthPackagePlatform(ownSourceId: flavor.bundleId),
      body: bodyRepository,
      nutrition: nutritionRepository,
      onError: (error, stack) =>
          unawaited(crashlytics.recordError(error, stack)),
    ),
    // The strava* callables are us-central1 and enforce App Check; the
    // tokens never leave the server.
    stravaRepository: stravaClientId.isEmpty
        ? null
        : StravaRepository(
            firestore: FirebaseFirestore.instance,
            api: RemoteStravaApi(
              callFunction: callStravaFunction(
                FirebaseFunctions.instanceFor(region: stravaFunctionsRegion),
              ),
              client: http.Client(),
            ),
            sessions: workoutSessionRepository,
            store: FileStravaAccountStore(Directory('${support.path}/strava')),
            clientId: stravaClientId,
            uploadContext: stravaUploadContext(
              users: userRepository,
              library: trainingLibraryRepository,
            ),
            onEvent: stravaEvents(analyticsRepository),
          ),
    // RevenueCat when the key is set (AppBloc logs in with the Firebase
    // uid). Otherwise nothing reaches RevenueCat: the premium fake, which
    // only development allows, since coachChat on compound-development
    // skips its premium check as dev builds do.
    purchasesRepository: flavor.revenueCatKey.isEmpty
        ? FakePurchasesRepository()
        : await RevenueCatPurchasesRepository.init(
            apiKey: flavor.revenueCatKey,
            appUserId: FirebaseAuth.instance.currentUser?.uid,
          ),
    // coachChat runs in europe-west4, beside the Firestore data it reads,
    // and enforces App Check.
    coachRepository: CoachRepository(
      firestore: FirebaseFirestore.instance,
      users: userRepository,
      coachChat: firebaseCoachChat(
        FirebaseFunctions.instanceFor(region: coachFunctionsRegion),
      ),
      onWriteError: onWriteError,
    ),
    activeSessionStore: FileActiveSessionStore(
      File('${support.path}/active_workout_session.json'),
    ),
    deviceStore: deviceStore,
    abTestRepository: await flavor.abTests(deviceStore),
    sessionWebLink: SessionWebLink(Uri.parse(flavor.sessionWebLinkBase)),
    analyticsRepository: analyticsRepository,
    authRepository: FirebaseAuthRepository(
      firebaseAuth: FirebaseAuth.instance,
      googleSignIn: GoogleSignIn.instance,
      googleClientId: options.iosClientId,
    ),
    userRepository: userRepository,
    notificationsRepository: notificationsRepository,
    liveActivityRepository: liveActivityRepository,
    appIntentsRepository: MethodChannelAppIntentsRepository(),
    homeWidgetRepository: MethodChannelHomeWidgetRepository(
      onError: (error, stackTrace) =>
          unawaited(crashlytics.recordError(error, stackTrace)),
    ),
    workoutSessionRepository: workoutSessionRepository,
    nutritionRepository: nutritionRepository,
    bodyRepository: bodyRepository,
    programRepository: FirestoreProgramRepository(
      firestore: FirebaseFirestore.instance,
    ),
    trainingLibraryRepository: trainingLibraryRepository,
    checkInRepository: FirestoreCheckInRepository(
      firestore: FirebaseFirestore.instance,
      onWriteError: onWriteError,
    ),
    // Swift's paths in the project's default bucket.
    imageRepository: FirebaseImageRepository(storage: FirebaseStorage.instance),
    photoPicker: DevicePhotoPicker(),
    labelTextReader: const PlatformLabelTextReader(),
    // The food photo, meal description and label callables are
    // us-central1 and enforce App Check.
    aiRepository: AiRepository(
      callFunction: callAiFunction(
        FirebaseFunctions.instanceFor(region: aiFunctionsRegion),
      ),
    ),
    foodRepository: FirestoreFoodRepository(
      firestore: FirebaseFirestore.instance,
      onWriteError: onWriteError,
    ),
    // foodSearch is a us-central1 callable that enforces App Check.
    openFoodFacts: RemoteOpenFoodFacts(
      functions: FirebaseFunctions.instanceFor(region: 'us-central1'),
      client: http.Client(),
    ),
    // The social callables are us-central1 and enforce App Check.
    socialRepository: SocialRepository(
      firestore: FirebaseFirestore.instance,
      callFunction: callFirebaseFunction(
        FirebaseFunctions.instanceFor(region: 'us-central1'),
      ),
      users: userRepository,
      onWriteError: onWriteError,
    ),
  );
}
