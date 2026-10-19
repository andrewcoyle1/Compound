import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/coach/coach.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/app_repositories.dart';

// The whole app on the staging flavor's in-memory data, signed in as the
// sample user: Ask Coach from Today and Weight Trend, consent, a streamed
// answer, the saved chats, opening and deleting one, withdrawing, Settings'
// Coach row, and the premium gate.
void main() {
  const uid = sampleUserId;
  final now = DateTime.now();

  Future<InMemoryUserRepository> pumpApp(
    WidgetTester tester, {
    String location = '/today',
    PurchasesRepository? purchases,
  }) async {
    tester.view
      ..physicalSize = const Size(1290, 2796)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final users = InMemoryUserRepository(
      users: {uid: sampleUser(now: now)},
      settings: {uid: sampleUserSettings(now: now)},
    );
    // As staging wires it.
    final coach = (await tester.runAsync(
      () => inMemoryCoachRepository(
        firestore: FakeFirebaseFirestore(),
        users: users,
        now: now,
      ),
    ))!;
    await tester.pumpWidget(
      App(
        socialRepository: emptySocialRepository(),
        purchasesRepository: purchases ?? FakePurchasesRepository(),
        coachRepository: coach,
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
        authRepository: InMemoryAuthRepository(
          user: InMemoryAuthRepository.sampleUser,
        ),
        userRepository: users,
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(
          measurements: sampleBodyMeasurements(uid: uid, now: now),
        ),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
    return users;
  }

  Finder askCoach() => find.descendant(
    of: find.byType(AppBar),
    matching: find.byTooltip('Ask Coach'),
  );

  Finder answers() => find.byWidgetPredicate(
    (widget) =>
        widget is CoachMessageBody && widget.role == CoachMessageRole.assistant,
  );

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Sends [finder]'s question and lets the answer stream in, word by word.
  Future<void> ask(WidgetTester tester, Finder finder) async {
    await tap(tester, finder);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  }

  testWidgets('from Today: consent, a streamed answer, the saved chats, '
      'delete, open and withdraw', (tester) async {
    final users = await pumpApp(tester);

    await tap(tester, askCoach().first);
    expect(find.text('Before You Ask'), findsOneWidget);
    await tap(tester, find.text('Allow and Continue'));

    expect(find.text('How did my training go this week?'), findsOneWidget);
    await ask(tester, find.text('How did my training go this week?'));
    expect(answers(), findsOneWidget);
    expect(
      (tester.widget(answers()) as CoachMessageBody).text,
      contains('bench press'),
    );
    // The suggestions are gone, and the chat takes its saved title.
    expect(find.text('Am I on track for my goal?'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('How did my training go this week?'),
      ),
      findsOneWidget,
    );

    await tap(tester, find.byTooltip('More'));
    await tap(tester, find.text('Chats'));
    expect(find.text('Coach Chats'), findsOneWidget);
    expect(find.text('Why has my weight stalled?'), findsOneWidget);
    expect(find.text('How did my training go this week?'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('CoachChats.chat-1')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Why has my weight stalled?'), findsNothing);

    await ask(tester, find.text('How did my training go this week?'));
    expect(answers(), findsOneWidget);
    await tap(tester, find.byType(BackButton));

    await tap(tester, find.text('Withdraw Permission and Delete Chats'));
    await tap(tester, find.text('Withdraw and Delete Chats'));
    expect(find.text('No Chats Yet'), findsOneWidget);
    expect(find.text('Withdraw Permission and Delete Chats'), findsNothing);
    expect(
      (await tester.runAsync(() => users.watchPrivateSettings(uid).first))
          ?.coachConsent,
      isFalse,
    );
  });

  testWidgets('from Weight Trend, about the trend', (tester) async {
    await pumpApp(tester, location: '/progress/weight-trend');

    await tap(tester, askCoach());
    await tap(tester, find.text('Allow and Continue'));

    expect(find.text('Weight Trend'), findsOneWidget);
    await ask(tester, find.text('Am I losing at the rate I planned?'));
    expect(
      (tester.widget(answers()) as CoachMessageBody).text,
      contains('trend weight'),
    );

    await tap(tester, find.byTooltip('Close'));
    expect(find.byType(CoachView), findsNothing);
  });

  testWidgets('typing a question sends it; Not Now closes the coach', (
    tester,
  ) async {
    await pumpApp(tester);

    await tap(tester, askCoach().first);
    await tap(tester, find.text('Not Now'));
    expect(find.byType(CoachView), findsNothing);

    await tap(tester, askCoach().first);
    await tap(tester, find.text('Allow and Continue'));
    await tester.enterText(
      find.byKey(const Key('Coach.draft')),
      'How is my week?',
    );
    await ask(tester, find.byTooltip('Send'));
    expect(answers(), findsOneWidget);

    await tap(tester, find.byTooltip('More'));
    await tap(tester, find.text('New Chat'));
    expect(answers(), findsNothing);
    expect(find.text('How did my training go this week?'), findsOneWidget);
  });

  testWidgets('Settings opens the saved chats', (tester) async {
    await pumpApp(tester, location: '/profile/settings');

    await tap(tester, find.text('Coach'));

    expect(find.text('Coach Chats'), findsOneWidget);
    expect(find.text('Why has my weight stalled?'), findsOneWidget);
    // No consent yet, so nothing to withdraw.
    expect(find.text('Withdraw Permission and Delete Chats'), findsNothing);

    await tap(tester, find.byTooltip('New Chat'));
    expect(find.text('Before You Ask'), findsOneWidget);
    // Lets any snack bar's timer run out.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('without Premium, the gate; See Plans opens the paywall, and '
      'buying unlocks the coach', (tester) async {
    final purchases = FakePurchasesRepository(premium: false);
    await pumpApp(tester, purchases: purchases);

    await tap(tester, askCoach().first);

    expect(find.text('Coach Is Part of Premium'), findsOneWidget);
    await tap(tester, find.text('See Plans'));
    expect(find.text('Pro Annual'), findsOneWidget);
    await tap(tester, find.text('Subscribe'));

    // Back on the coach, which reads the gate again: consent is next.
    expect(find.text('Pro Annual'), findsNothing);
    expect(find.text('Coach Is Part of Premium'), findsNothing);
    expect(find.text('Before You Ask'), findsOneWidget);
    expect(purchases.state.isPremiumWith(), isTrue);
  });
}
