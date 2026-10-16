import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:ai_repository/ai_repository.dart';
import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/bootstrap.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:compound/firebase_options_development.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/notifications/notifications.dart';
import 'package:compound_models/compound_models.dart' show logWriteError;
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

/// The Mixpanel project token, from a gitignored file:
/// `--dart-define-from-file=dart_defines.json` (see the README). Mixpanel is
/// off when it's empty. Never commit it.
const _mixpanelToken = String.fromEnvironment('MIXPANEL_TOKEN');

/// Strava's client id for the dev Strava app, from the same gitignored
/// file. Strava shows as unavailable when it's empty.
const _stravaClientId = String.fromEnvironment('STRAVA_CLIENT_ID');

/// The development flavor: the `compound-development` Firebase project.
Future<void> main() async {
  await bootstrap(() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    await Firebase.initializeApp(options: options);
    // Debug providers: the token is printed to the device log on first run
    // and must be registered in the compound-development console before
    // App Check is enforced.
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidDebugProvider(),
      providerApple: const AppleDebugProvider(),
    );
    final crashlytics = FirebaseCrashlytics.instance;
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(crashlytics.recordError(error, stack, fatal: true));
      return true;
    };
    final analyticsRepository = AnalyticsRepository(
      services: [
        const ConsoleService(),
        FirebaseAnalyticsService(analytics: FirebaseAnalytics.instance),
        CrashlyticsService(crashlytics: crashlytics),
        if (_mixpanelToken.isNotEmpty)
          await MixpanelService.init(
            token: _mixpanelToken,
            buildConfiguration: 'dev',
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

    // The workout under way, kept on the device between launches.
    final support = await getApplicationSupportDirectory();
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
    if (_stravaClientId.isEmpty) {
      developer.log(
        'STRAVA_CLIENT_ID is not set (dart_defines.json): Strava is '
        'unavailable in this build',
        name: 'strava',
      );
    }
    return App(
      // The flavor's own bundle id and package name, which Health reports
      // as the source of what this app wrote.
      healthRepository: HealthRepository(
        platform: HealthPackagePlatform(
          ownSourceId: Platform.isIOS
              ? 'com.andrewcoyle.compound.flutter.dev'
              : 'com.andrewcoyle.compound.dev',
        ),
        body: bodyRepository,
        nutrition: nutritionRepository,
        onError: (error, stack) =>
            unawaited(crashlytics.recordError(error, stack)),
      ),
      // The strava* callables are us-central1 and enforce App Check; the
      // tokens never leave the server.
      stravaRepository: _stravaClientId.isEmpty
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
              store: FileStravaAccountStore(
                Directory('${support.path}/strava'),
              ),
              clientId: _stravaClientId,
              uploadContext: stravaUploadContext(
                users: userRepository,
                library: trainingLibraryRepository,
              ),
              onEvent: stravaEvents(analyticsRepository),
            ),
      // Premium for now: RevenueCat's logIn isn't wired yet (the paywall
      // slice does it), and coachChat on compound-development skips its
      // premium check as dev builds do. Never copy this to production.
      purchasesRepository: FakePurchasesRepository(),
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
      analyticsRepository: analyticsRepository,
      authRepository: FirebaseAuthRepository(
        firebaseAuth: FirebaseAuth.instance,
        googleSignIn: GoogleSignIn.instance,
        googleClientId: options.iosClientId,
      ),
      userRepository: userRepository,
      notificationsRepository: notificationsRepository,
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
      proposalDismissals: ProposalDismissals(
        file: File('${support.path}/dismissed_target_proposals.json'),
      ),
      // Swift's paths in the compound-development bucket.
      imageRepository: FirebaseImageRepository(
        storage: FirebaseStorage.instance,
      ),
      photoPicker: DevicePhotoPicker(),
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
  });
}
