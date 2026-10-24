import 'package:app_ui/app_ui.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/coach/coach.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

/// One chat a day: the list of days, a past day read-only, the questions
/// about the screen the coach was opened from, and a day ending mid-chat.
void main() {
  const uid = 'user-1';
  final asked = DateTime(2026, 10, 21, 9);
  late FakeFirebaseFirestore firestore;
  late InMemoryUserRepository users;
  late CoachFailure? refusal;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    users = InMemoryUserRepository();
    await users.mergePrivateSettings(
      uid,
      const PrivateUserSettings(coachConsent: true),
    );
    refusal = null;
  });

  CoachRepository coach() => CoachRepository(
    firestore: firestore,
    users: users,
    coachChat: (_, {chatId, context, regenerate = false}) => refusal == null
        ? Stream.value(
            CoachFinished(
              chatId: chatId!,
              messageId: 'a1',
              text: 'Fine.',
              remainingToday: 40,
            ),
          )
        : Stream.error(CoachException(refusal!)),
  );

  CoachChat chat(String id, String title, DateTime createdAt, {String? day}) =>
      CoachChat(
        id: id,
        day: day,
        title: title,
        createdAt: createdAt,
        updatedAt: createdAt.add(const Duration(minutes: 5)),
        messages: [
          CoachMessage(
            id: '$id-q',
            role: CoachMessageRole.user,
            text: title,
            createdAt: createdAt,
          ),
          CoachMessage(
            id: '$id-a',
            role: CoachMessageRole.assistant,
            text: 'An answer.',
            createdAt: createdAt,
          ),
        ],
      );

  Future<void> pumpCoach(WidgetTester tester, CoachRequest request) async {
    final purchases = FakePurchasesRepository();
    await purchases.logIn(uid);
    var ids = 0;
    final cubit = CoachCubit(
      uid: uid,
      request: request,
      coach: coach(),
      purchases: purchases,
      analytics: AnalyticsRecorder(),
      now: () => asked,
      newId: () => 'q${++ids}',
    );
    await tester.pumpApp(
      BlocProvider.value(
        value: cubit,
        child: CoachView(request: request),
      ),
    );
    await cubit.appeared();
    await tester.pumpAndSettle();
  }

  testWidgets('the list is of days, newest first: a day chat under its day, '
      'an older chat under the day it began', (tester) async {
    for (final saved in [
      chat('2026-10-21', 'Today Q', asked, day: '2026-10-21'),
      chat('legacy-today', 'Earlier today', DateTime(2026, 10, 21, 7)),
      chat('old', 'Yesterday Q', DateTime(2026, 10, 20, 18)),
    ]) {
      await firestore
          .doc('users/$uid/coach_chats/${saved.id}')
          .set(saved.toFirestore());
    }
    await tester.pumpApp(
      BlocProvider(
        create: (_) => CoachChatsCubit(
          uid: uid,
          coach: coach(),
          analytics: AnalyticsRecorder(),
        )..started(),
        child: const CoachChatsView(coachContext: CoachContext.today),
      ),
    );
    await tester.pumpAndSettle();

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Wed, Oct 21, 2026'), lessThan(top('Today Q')));
    expect(top('Today Q'), lessThan(top('Earlier today')));
    expect(top('Earlier today'), lessThan(top('Tue, Oct 20, 2026')));
    expect(top('Tue, Oct 20, 2026'), lessThan(top('Yesterday Q')));
  });

  testWidgets('a past day is read-only: no field, no day, no Regenerate; a '
      'footer sends the asker to today', (tester) async {
    await pumpCoach(
      tester,
      CoachRequest.forChat(
        chat(
          '2026-10-19',
          'How was Monday?',
          DateTime(2026, 10, 19, 9),
          day: '2026-10-19',
        ),
        CoachContext.today,
      ),
    );

    expect(find.text('Mon, Oct 19, 2026'), findsOneWidget);
    expect(find.byKey(const Key('Coach.draft')), findsNothing);
    expect(find.text('This day has ended.'), findsOneWidget);
    expect(find.text("Ask in Today's Chat"), findsOneWidget);
    expect(find.byTooltip('Chats'), findsNothing);
    expect(find.text('How did my training go this week?'), findsNothing);

    await tester.longPress(find.text('An answer.', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Helpful'), findsOneWidget);
    expect(find.text('Regenerate'), findsNothing);
  });

  testWidgets('opened from a screen, its questions sit above the field until '
      'one is asked', (tester) async {
    await pumpCoach(
      tester,
      const CoachRequest(
        context: CoachContext(
          kind: CoachContextKind.exercise,
          id: 'bench',
          title: 'Bench Press',
        ),
      ),
    );

    expect(find.text('Bench Press'), findsOneWidget);
    // Not Today's questions.
    expect(find.text('How did my training go this week?'), findsNothing);
    final question = find.descendant(
      of: find.byType(AppSection),
      matching: find.byType(AppListRowButton),
    );
    expect(question, findsNWidgets(3));

    await tester.tap(question.first);
    await tester.pumpAndSettle();
    expect(find.text('Bench Press'), findsNothing);
    expect(find.text('Fine.', findRichText: true), findsOneWidget);
  });

  testWidgets('a day that ends mid-chat moves to the new one, saying so, '
      'with the question kept', (tester) async {
    refusal = CoachFailure.pastDay;
    await pumpCoach(tester, const CoachRequest());

    await tester.enterText(find.byKey(const Key('Coach.draft')), 'Still up?');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.textContaining('A new day has started'), findsOneWidget);
    expect(find.text('Still up?'), findsOneWidget);
    expect(find.byType(CoachMessageBody), findsNothing);
  });
}
