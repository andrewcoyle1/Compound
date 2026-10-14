import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/bootstrap.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// The staging flavor, which is the Swift app's old Mock configuration:
/// in-memory repositories and no Firebase, for previews and demos. Starts
/// signed in as the seeded sample user; signing out and back in stays in
/// memory.
Future<void> main() async {
  final now = DateTime.now();
  await bootstrap(
    () => App(
      authRepository: InMemoryAuthRepository(
        user: InMemoryAuthRepository.sampleUser,
      ),
      userRepository: InMemoryUserRepository(
        users: {sampleUserId: sampleUser(now: now)},
        settings: {sampleUserId: sampleUserSettings(now: now)},
      ),
      workoutSessionRepository: InMemoryWorkoutSessionRepository(
        sessions: sampleWorkoutSessions(uid: sampleUserId, now: now),
      ),
    ),
  );
}
