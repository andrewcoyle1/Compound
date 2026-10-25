import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart' show localDayKey;
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/coach/coach.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
// sample user: Today as the coach's day chat and Ask Coach from Weight
// Trend, consent, a streamed answer, the saved chats, opening and deleting
// one, withdrawing, Settings' Coach section, and premium.
/// The day's checklist: Today's hero card ("YOUR DAY") or the coach
/// chat's day card ("Your Day").
final Finder _yourDay = find.textContaining(
  RegExp(r'^Your Day$', caseSensitive: false),
);

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

    // Today is the day's chat; before consent it asks to turn it on.
    expect(_yourDay, findsOneWidget);
    expect(find.byKey(const Key('Coach.draft')), findsNothing);
    await tap(tester, find.text('Turn On Coach'));
    expect(find.text('Before You Ask'), findsOneWidget);
    await tap(tester, find.text('Allow and Continue'));

    // Back on Today, which is now the chat, under the day.
    expect(find.byType(CoachView), findsNothing);
    expect(_yourDay, findsOneWidget);
    expect(find.byKey(const Key('Coach.draft')), findsOneWidget);
    // The suggestions, under the day.
    final chat = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('How did my training go this week?'),
      300,
      scrollable: chat,
    );
    await ask(tester, find.text('How did my training go this week?'));
    expect(answers(), findsOneWidget);
    expect(
      (tester.widget(answers()) as CoachMessageBody).text,
      contains('bench press'),
    );
    // The suggestions are gone; the day stays, above.
    expect(find.text('Am I on track for my goal?'), findsNothing);
    await tester.scrollUntilVisible(_yourDay, -300, scrollable: chat);

    await tap(tester, find.byTooltip('Chats'));
    expect(find.text('Coach Chats'), findsOneWidget);
    // Yesterday's chat, from before day chats, and today's.
    expect(find.text('Why has my weight stalled?'), findsOneWidget);
    expect(find.byKey(Key('CoachChats.${localDayKey(now)}')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('CoachChats.chat-1')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Why has my weight stalled?'), findsNothing);

    // Today's chat, from the list, is still today's.
    await tap(tester, find.byKey(Key('CoachChats.${localDayKey(now)}')));
    expect(answers(), findsOneWidget);
    expect(find.byKey(const Key('Coach.draft')), findsOneWidget);
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
    // Its blocks follow it, live, so undated.
    expect(find.byType(CoachSurface), findsNWidgets(3));
    expect(find.textContaining('As of'), findsNothing);

    // A follow-up asks the next question.
    await ask(tester, find.text('Is my protein high enough?'));
    final messages = tester
        .element(find.byType(CoachView))
        .read<CoachCubit>()
        .state
        .messages;
    expect(messages.map((m) => m.text), hasLength(4));
    expect(messages[2].text, 'Is my protein high enough?');

    // An action opens its screen over the coach.
    await tap(tester, find.text('Log Weight').first);
    expect(find.byType(LogWeightPage), findsOneWidget);
    GoRouter.of(tester.element(find.byType(LogWeightPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(CoachView), findsOneWidget);

    await tap(tester, find.byTooltip('Close'));
    expect(find.byType(CoachView), findsNothing);
  });

  testWidgets('typing a question sends it; Not Now closes the coach', (
    tester,
  ) async {
    await pumpApp(tester);

    await tap(tester, find.text('Turn On Coach'));
    await tap(tester, find.text('Not Now'));
    expect(find.byType(CoachView), findsNothing);
    expect(find.text('Turn On Coach'), findsOneWidget);

    await tap(tester, find.text('Turn On Coach'));
    await tap(tester, find.text('Allow and Continue'));
    await tester.enterText(
      find.byKey(const Key('Coach.draft')),
      'How is my week?',
    );
    await ask(tester, find.byTooltip('Send'));
    expect(answers(), findsOneWidget);
  });

  testWidgets('Settings opens the saved chats', (tester) async {
    await pumpApp(tester, location: '/profile/settings');

    await tap(tester, find.text('Chats'));

    expect(find.text('Coach Chats'), findsOneWidget);
    expect(find.text('Why has my weight stalled?'), findsOneWidget);
    // No consent yet, so nothing to withdraw.
    expect(find.text('Withdraw Permission and Delete Chats'), findsNothing);

    // A past day reads, and sends its asker to today.
    await tap(tester, find.text('Why has my weight stalled?'));
    await tap(tester, find.text('Allow and Continue'));
    expect(find.text('This day has ended.'), findsOneWidget);
    expect(find.byKey(const Key('Coach.draft')), findsNothing);
    expect(_yourDay, findsNothing);
    await tap(tester, find.text("Ask in Today's Chat"));
    expect(_yourDay, findsOneWidget);
    expect(find.byKey(const Key('Coach.draft')), findsOneWidget);
    await tap(tester, find.byType(BackButton));
    expect(find.text('Coach Chats'), findsOneWidget);
    // Lets any snack bar's timer run out.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('without Premium there is no coach; Settings opens the plans, '
      'and buying turns it on', (tester) async {
    final purchases = FakePurchasesRepository(premium: false);
    await pumpApp(tester, purchases: purchases);

    // The classic Today, and no way to the coach.
    expect(_yourDay, findsOneWidget);
    expect(find.byKey(const Key('Coach.draft')), findsNothing);
    expect(find.text('Turn On Coach'), findsNothing);
    expect(askCoach(), findsNothing);

    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/profile/settings');
    await tester.pumpAndSettle();
    expect(find.text('Premium'), findsOneWidget);
    await tap(tester, find.text('AI Coach'));
    expect(find.text('Pro Annual'), findsOneWidget);
    await tap(tester, find.text('Subscribe'));

    expect(purchases.state.isPremiumWith(), isTrue);
    expect(find.text('Premium'), findsNothing);
    expect(find.widgetWithText(AppListRowToggle, 'AI Coach'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/today');
    await tester.pumpAndSettle();
    expect(find.text('Turn On Coach'), findsOneWidget);
  });

  testWidgets('the switch in Settings turns Today back to the day, and '
      'hides Ask Coach', (tester) async {
    await pumpApp(tester, location: '/profile/settings');

    await tap(tester, find.text('AI Coach'));
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/today');
    await tester.pumpAndSettle();
    expect(find.text('Turn On Coach'), findsNothing);
    expect(_yourDay, findsOneWidget);

    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/progress/weight-trend');
    await tester.pumpAndSettle();
    expect(askCoach(), findsNothing);
  });
}
