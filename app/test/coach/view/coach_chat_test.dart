import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/coach/coach.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

/// The chat itself: the answer as prose, Stop, a failed question kept with
/// Retry, the long-press actions, and how the list scrolls.
void main() {
  const uid = 'user-1';
  final asked = DateTime.utc(2026, 10, 21, 9);
  late List<StreamController<CoachStreamEvent>> answers;
  late AnalyticsRecorder analytics;
  late List<AppHaptic> haptics;

  setUp(() {
    answers = [];
    analytics = AnalyticsRecorder();
    haptics = [];
    AppHaptics.debugPlay = haptics.add;
  });
  tearDown(() => AppHaptics.debugPlay = null);

  CoachMessage message(String id, CoachMessageRole role, String text) =>
      CoachMessage(id: id, role: role, text: text, createdAt: asked);

  /// A long answer, so the conversation scrolls.
  final long = List.filled(40, 'Your trend is down 0.4 kg a week.').join(' ');

  Future<CoachCubit> pumpChat(
    WidgetTester tester, {
    List<CoachMessage> saved = const [],
    bool disableAnimations = true,
  }) async {
    final users = InMemoryUserRepository();
    await users.mergePrivateSettings(
      uid,
      const PrivateUserSettings(coachConsent: true),
    );
    final purchases = FakePurchasesRepository();
    await purchases.logIn(uid);
    final request = CoachRequest(
      chat: saved.isEmpty
          ? null
          : CoachChat(
              id: 'chat-1',
              title: 'Weight',
              createdAt: asked,
              updatedAt: asked,
              messages: saved,
            ),
    );
    var ids = 0;
    final cubit = CoachCubit(
      uid: uid,
      request: request,
      coach: CoachRepository(
        firestore: FakeFirebaseFirestore(),
        users: users,
        coachChat: (_, {chatId, context, regenerate = false}) {
          answers.add(StreamController<CoachStreamEvent>());
          return answers.last.stream;
        },
      ),
      purchases: purchases,
      analytics: analytics,
      now: () => asked,
      newId: () => 'q${++ids}',
    );
    await tester.pumpApp(
      BlocProvider.value(
        value: cubit,
        child: CoachView(request: request),
      ),
      disableAnimations: disableAnimations,
    );
    await cubit.appeared();
    await tester.pumpAndSettle();
    return cubit;
  }

  Future<void> send(WidgetTester tester, String question) async {
    await tester.enterText(find.byKey(const Key('Coach.draft')), question);
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pump();
  }

  void finish(String text) {
    answers.last.add(
      CoachFinished(
        chatId: 'chat-1',
        messageId: 'a${answers.length}',
        text: text,
        remainingToday: 40,
      ),
    );
    unawaited(answers.last.close());
  }

  ScrollPosition position(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  testWidgets('the answer is prose; the question a bubble', (tester) async {
    await pumpChat(
      tester,
      saved: [
        message('m1', CoachMessageRole.user, 'How am I doing?'),
        message('m2', CoachMessageRole.assistant, 'Well.'),
      ],
    );

    expect(
      find.ancestor(
        of: find.text('Well.', findRichText: true),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.text('How am I doing?', findRichText: true),
        matching: find.byType(Container),
      ),
      findsWidgets,
    );
  });

  testWidgets('Send becomes Stop while answering; Stop keeps the question, '
      'stopped, with Retry', (tester) async {
    final cubit = await pumpChat(tester);
    expect(
      tester.widget<AppIconButton>(find.byType(AppIconButton)).onPressed,
      isNull,
    );

    await send(tester, 'How is my week?');
    expect(haptics, [AppHaptic.light]);
    expect(find.byTooltip('Send'), findsNothing);
    answers.last.add(const CoachText('Your week '));
    await tester.pump();
    expect(find.text('Your week', findRichText: true), findsOneWidget);

    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();

    expect(find.textContaining('Your week', findRichText: true), findsNothing);
    expect(find.text('How is my week?', findRichText: true), findsOneWidget);
    expect(find.text('Stopped'), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    finish('Good.');
    await tester.pumpAndSettle();

    expect(find.text('Stopped'), findsNothing);
    expect(cubit.state.messages.map((m) => m.text), [
      'How is my week?',
      'Good.',
    ]);
  });

  testWidgets('a failed question stays with its reason and Retry; the day '
      "limit's has no Retry", (tester) async {
    await pumpChat(tester);

    await send(tester, 'How is my week?');
    answers.last.addError(const CoachException(CoachFailure.unavailable));
    await tester.pumpAndSettle();

    expect(find.text('How is my week?', findRichText: true), findsOneWidget);
    expect(
      find.text("The coach isn't available right now. Try again in a moment."),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(haptics, [AppHaptic.light, AppHaptic.error]);
    // The field is free for the next question.
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('Coach.draft')))
          .controller
          ?.text,
      isEmpty,
    );

    await send(tester, 'And today?');
    answers.last.addError(const CoachException(CoachFailure.dailyLimitReached));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a finished answer is read out', (tester) async {
    await pumpChat(tester);

    await send(tester, 'Hi');
    finish('**Hello** there');
    await tester.pumpAndSettle();

    expect(
      tester.takeAnnouncements().map((a) => a.message),
      contains('Coach: Hello there'),
    );
  });

  group('a long press', () {
    final saved = [
      message('m1', CoachMessageRole.user, 'How am I doing?'),
      message('m2', CoachMessageRole.assistant, 'You are **on track**.'),
    ];

    testWidgets('copies a message as plain text', (tester) async {
      final copied = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') copied.add(call.arguments);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpChat(tester, saved: saved);

      await tester.longPress(
        find.text('You are on track.', findRichText: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(copied, [
        {'text': 'You are on track.'},
      ]);
      expect(find.text('Copied'), findsOneWidget);
      expect(analytics.parameters('CoachView_Copy_Press'), {
        'context': 'today',
        'role': 'assistant',
      });
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets("rates an answer, not a question's", (tester) async {
      await pumpChat(tester, saved: saved);

      await tester.longPress(find.text('How am I doing?', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Helpful'), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await tester.longPress(
        find.text('You are on track.', findRichText: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not Helpful'));
      await tester.pumpAndSettle();

      expect(analytics.parameters('CoachView_Feedback'), {
        'context': 'today',
        'rating': 'down',
      });
      expect(find.text('Thanks for the feedback'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('offers the same actions to screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpChat(tester, saved: saved);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Coach: You are on track.')),
        matchesSemantics(
          label: 'Coach: You are on track.',
          customActions: const [
            CustomSemanticsAction(label: 'Copy'),
            CustomSemanticsAction(label: 'Regenerate'),
            CustomSemanticsAction(label: 'Helpful'),
            CustomSemanticsAction(label: 'Not Helpful'),
          ],
        ),
      );
      semantics.dispose();
    });
  });

  group('while answering', () {
    const block = CoachBlock(
      surfaceId: 'a1-0',
      kind: 'stat_row',
      asOf: '2026-10-21',
      fallback: 'Calories today: 1,640 kcal.',
      messages: [],
    );

    testWidgets('a line says what the coach reads, until text follows', (
      tester,
    ) async {
      await pumpChat(tester);
      await send(tester, 'How is my week?');
      expect(find.text('Thinking…'), findsOneWidget);

      answers.last.add(const CoachStatus('get_workout_history'));
      await tester.pumpAndSettle();
      expect(find.text('Reading your workouts…'), findsOneWidget);
      expect(find.text('Thinking…'), findsNothing);
      expect(find.byType(AppSpinner), findsOneWidget);

      answers.last.add(const CoachStatus('get_nutrition'));
      await tester.pumpAndSettle();
      expect(find.text('Checking your nutrition…'), findsOneWidget);
      expect(find.text('Reading your workouts…'), findsNothing);

      answers.last.add(const CoachText('You trained 4 times.'));
      await tester.pumpAndSettle();
      expect(find.text('Checking your nutrition…'), findsNothing);
      expect(find.byType(AppSpinner), findsNothing);

      // Another tool after some text: the line comes back below it.
      answers.last.add(const CoachStatus('get_a_tool_from_later'));
      await tester.pumpAndSettle();
      expect(find.text('Thinking…'), findsOneWidget);

      finish('You trained 4 times.');
      await tester.pumpAndSettle();
      expect(find.text('Thinking…'), findsNothing);
    });

    testWidgets('a placeholder holds the place of a block being laid out', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpChat(tester);
      await send(tester, 'How is my week?');
      answers.last
        ..add(const CoachText('Here it is.'))
        ..add(const CoachStatus('show_block'));
      await tester.pumpAndSettle();

      expect(find.byType(AppPlaceholder), findsOneWidget);
      expect(find.bySemanticsLabel('Adding a card…'), findsOneWidget);
      expect(find.text('Thinking…'), findsNothing);

      answers.last.add(const CoachBlockShown(block));
      await tester.pumpAndSettle();
      expect(find.byType(AppPlaceholder), findsNothing);
      expect(find.byType(CoachSurface), findsOneWidget);

      // One that never arrives goes when the answer ends.
      answers.last.add(const CoachStatus('show_block'));
      await tester.pumpAndSettle();
      expect(find.byType(AppPlaceholder), findsOneWidget);
      finish('Here it is.');
      await tester.pumpAndSettle();
      expect(find.byType(AppPlaceholder), findsNothing);
      semantics.dispose();
    });
  });

  group('Regenerate', () {
    final saved = [
      message('m1', CoachMessageRole.user, 'How am I doing?'),
      message('m2', CoachMessageRole.assistant, 'You are on track.'),
    ];

    Future<void> regenerate(WidgetTester tester) async {
      await tester.longPress(
        find.text('You are on track.', findRichText: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regenerate'));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('is offered on the latest answer only', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpChat(
        tester,
        saved: [
          ...saved,
          message('m3', CoachMessageRole.user, 'And now?'),
          message('m4', CoachMessageRole.assistant, 'Still on track.'),
        ],
      );

      List<String> actions(String label) => [
        for (final action
            in tester
                .getSemantics(find.bySemanticsLabel(label))
                .getSemanticsData()
                .customSemanticsActionIds!)
          CustomSemanticsAction.getAction(action)!.label!,
      ];
      expect(actions('Coach: You are on track.'), [
        'Copy',
        'Helpful',
        'Not Helpful',
      ]);
      expect(actions('Coach: Still on track.'), contains('Regenerate'));
      semantics.dispose();
    });

    testWidgets('replaces the answer in place', (tester) async {
      await pumpChat(tester, saved: saved);

      await regenerate(tester);

      expect(find.text('You are on track.', findRichText: true), findsNothing);
      expect(find.text('How am I doing?', findRichText: true), findsOneWidget);
      expect(find.text('Thinking…'), findsOneWidget);
      expect(analytics.parameters('CoachView_Regenerate_Press'), {
        'context': 'today',
      });

      finish('You are ahead of plan.');
      await tester.pumpAndSettle();
      expect(
        find.text('You are ahead of plan.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('You are on track.', findRichText: true), findsNothing);
    });

    testWidgets('brings the old answer back when it fails', (tester) async {
      await pumpChat(tester, saved: saved);

      await regenerate(tester);
      answers.last.addError(const CoachException(CoachFailure.unavailable));
      await tester.pumpAndSettle();

      expect(
        find.text('You are on track.', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text("Couldn't get a new answer. Try again."),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
      // The old answer is not read out as new.
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        isNot(contains('Coach: You are on track.')),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('scrolling', () {
    final saved = [
      message('m1', CoachMessageRole.user, 'Earlier?'),
      message('m2', CoachMessageRole.assistant, long),
    ];

    testWidgets('a saved chat opens on its latest exchange', (tester) async {
      await pumpChat(tester, saved: saved);

      final scroll = position(tester);
      expect(scroll.pixels, scroll.maxScrollExtent);
      expect(find.text('Jump to Latest'), findsNothing);
    });

    testWidgets('sending brings the question to the top, and the answer '
        'is followed down while the reader stays at the bottom', (
      tester,
    ) async {
      await pumpChat(tester, saved: saved);

      await send(tester, 'And now?');
      await tester.pumpAndSettle();
      final list = tester.getTopLeft(find.byType(ListView));
      final question = tester.getTopLeft(
        find.text('And now?', findRichText: true),
      );
      expect(question.dy - list.dy, lessThan(AppSpacing.xxl * 2));

      answers.last.add(CoachText(long));
      await tester.pumpAndSettle();
      final scroll = position(tester);
      expect(scroll.pixels, scroll.maxScrollExtent);
      expect(find.text('Jump to Latest'), findsNothing);
    });

    testWidgets('never pulls a reader who scrolled up down; Jump to Latest '
        'takes them there', (tester) async {
      await pumpChat(tester, saved: saved);
      await send(tester, 'And now?');
      answers.last.add(CoachText(long));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      final scroll = position(tester);
      final reading = scroll.pixels;
      expect(reading, lessThan(scroll.maxScrollExtent));
      expect(find.text('Jump to Latest'), findsOneWidget);

      answers.last.add(CoachText(' $long'));
      await tester.pumpAndSettle();
      expect(scroll.pixels, reading);

      await tester.tap(find.text('Jump to Latest'));
      await tester.pumpAndSettle();
      expect(scroll.pixels, scroll.maxScrollExtent);
      expect(find.text('Jump to Latest'), findsNothing);

      // Following again.
      answers.last.add(CoachText(' $long'));
      await tester.pumpAndSettle();
      expect(scroll.pixels, scroll.maxScrollExtent);
    });

    testWidgets('scrolling back to the bottom follows again; with motion, '
        'sending glides there', (tester) async {
      await pumpChat(tester, saved: saved, disableAnimations: false);
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text('Jump to Latest'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.text('Jump to Latest'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      await send(tester, 'And now?');
      await tester.pump(const Duration(milliseconds: 100));
      final scroll = position(tester);
      expect(scroll.pixels, lessThan(scroll.maxScrollExtent));
      // The spinner turns until the answer starts, so no settling.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
      expect(scroll.pixels, scroll.maxScrollExtent);
      expect(find.text('Jump to Latest'), findsNothing);
      answers.last.addError(const CoachException(CoachFailure.failed));
      await tester.pumpAndSettle();
    });
  });

  group('streaming text', () {
    String shown(WidgetTester tester) => tester
        .widget<AppMarkdownText>(
          find
              .descendant(
                of: find.byWidgetPredicate(
                  (widget) => widget is CoachMessageBody && widget.streaming,
                ),
                matching: find.byType(AppMarkdownText),
              )
              .first,
        )
        .data;

    testWidgets('is revealed at a steady pace, not in chunks', (tester) async {
      await pumpChat(tester, disableAnimations: false);
      await send(tester, 'Hi');

      answers.last.add(const CoachText('Your trend is 😀 down 0.4 kg a week.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final early = shown(tester);
      expect(early, isNotEmpty);
      expect(early.length, lessThan(36));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(shown(tester), 'Your trend is 😀 down 0.4 kg a week.');
      answers.last.addError(const CoachException(CoachFailure.failed));
      await tester.pumpAndSettle();
    });

    testWidgets('is all there at once under reduced motion', (tester) async {
      await pumpChat(tester);
      await send(tester, 'Hi');

      answers.last.add(const CoachText('Your trend is down.'));
      await tester.pump();
      expect(shown(tester), 'Your trend is down.');
      answers.last.addError(const CoachException(CoachFailure.failed));
      await tester.pumpAndSettle();
    });
  });
}
