import 'package:auth_repository/auth_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound/app/app.dart';
import 'package:compound/bootstrap.dart';
import 'package:compound/firebase_options_development.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:user_repository/user_repository.dart';

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
    return App(
      authRepository: FirebaseAuthRepository(
        firebaseAuth: FirebaseAuth.instance,
        googleSignIn: GoogleSignIn.instance,
        googleClientId: options.iosClientId,
      ),
      userRepository: FirestoreUserRepository(
        firestore: FirebaseFirestore.instance,
      ),
    );
  });
}
