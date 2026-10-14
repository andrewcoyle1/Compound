import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound/app/app.dart';
import 'package:compound/bootstrap.dart';
import 'package:compound/firebase_options_development.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// The Mixpanel project token, from a gitignored file:
/// `--dart-define-from-file=dart_defines.json` (see the README). Mixpanel is
/// off when it's empty. Never commit it.
const _mixpanelToken = String.fromEnvironment('MIXPANEL_TOKEN');

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
    return App(
      analyticsRepository: analyticsRepository,
      authRepository: FirebaseAuthRepository(
        firebaseAuth: FirebaseAuth.instance,
        googleSignIn: GoogleSignIn.instance,
        googleClientId: options.iosClientId,
      ),
      userRepository: FirestoreUserRepository(
        firestore: FirebaseFirestore.instance,
      ),
      workoutSessionRepository: FirestoreWorkoutSessionRepository(
        firestore: FirebaseFirestore.instance,
      ),
      nutritionRepository: FirestoreNutritionRepository(
        firestore: FirebaseFirestore.instance,
      ),
      bodyRepository: FirestoreBodyRepository(
        firestore: FirebaseFirestore.instance,
      ),
    );
  });
}
