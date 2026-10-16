import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/social/profile/social_profile_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:social_repository/social_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

/// Invites through the whole app: a `compound://join/` link, and sharing
/// the viewer's own link (`InviteTests`).
void main() {
  late ShareRecorder shares;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> pump(WidgetTester tester) async {
    final now = DateTime.now();
    final users = InMemoryUserRepository(
      users: {sampleUserId: sampleUser(now: now)},
      settings: {sampleUserId: sampleUserSettings(now: now)},
    );
    final social = (await tester.runAsync(
      () => inMemorySocialRepository(users: users, now: now),
    ))!;
    shares = ShareRecorder();
    await tester.pumpWidget(
      App(
        purchasesRepository: FakePurchasesRepository(),
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
        authRepository: InMemoryAuthRepository(
          user: InMemoryAuthRepository.sampleUser,
        ),
        userRepository: users,
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: sampleWorkoutSessions(uid: sampleUserId, now: now),
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
        socialRepository: social,
        shareSheet: shares,
      ),
    );
    await settle(tester);
  }

  Future<void> open(WidgetTester tester, String url) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', {'location': url}),
      ),
      (_) {},
    );
    await settle(tester);
  }

  // InviteTests.testSocialAcceptsARelayedInvite and
  // testAcceptingOpensTheInviterWithAFollowingToast
  testWidgets("a join link opens the inviter's profile and says so", (
    tester,
  ) async {
    await pump(tester);
    await open(tester, 'compound://join/PUSH2345');
    expect(find.byType(SocialProfilePage), findsOneWidget);
    expect(find.text('@maya.chen'), findsOneWidget);
    expect(find.text("You're now following each other"), findsOneWidget);
  });

  // InviteTests.testARefusedInviteExplainsWhyAndOpensNothing
  testWidgets('a refused invite explains why and opens nothing', (
    tester,
  ) async {
    await pump(tester);
    await open(tester, 'compound://join/ABCDEFGH');
    expect(find.byType(SocialProfilePage), findsNothing);
    expect(
      find.text("Couldn't accept invite. That invite code doesn't exist."),
      findsOneWidget,
    );
  });

  testWidgets('Invite a Friend hands the link to the share sheet', (
    tester,
  ) async {
    await pump(tester);
    await open(tester, 'compound://tab/social');
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.tap(find.text('Invite a Friend'));
    await settle(tester);
    expect(shares.texts, hasLength(1));
    expect(
      shares.texts.single,
      matches(RegExp(r'^Train with me on Compound: compound://join/\w{8}$')),
    );
  });
}
