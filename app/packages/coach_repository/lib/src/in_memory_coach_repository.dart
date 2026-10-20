import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coach_repository/src/coach_chat_call.dart';
import 'package:coach_repository/src/coach_repository.dart';
import 'package:compound_models/compound_models.dart';
import 'package:user_repository/user_repository.dart';

/// A [CoachRepository] for the staging flavor: the real repository over
/// [firestore], an in-memory one (`FakeFirebaseFirestore`, which the staging
/// entry point brings, so release builds never depend on it), given
/// [signedInUid]'s sample chat (Swift `CoachChat.mocks`) and answered by
/// [stagingCoachChat].
Future<CoachRepository> inMemoryCoachRepository({
  required FirebaseFirestore firestore,
  required UserRepository users,
  required DateTime now,
  String signedInUid = sampleUserId,
}) async {
  final asked = now.subtract(const Duration(days: 1));
  await firestore
      .doc('users/$signedInUid/coach_chats/chat-1')
      .set(
        CoachChat(
          id: 'chat-1',
          title: 'Why has my weight stalled?',
          createdAt: asked,
          updatedAt: asked.add(const Duration(minutes: 1)),
          contextKind: CoachContextKind.weightTrend.value,
          messages: [
            CoachMessage(
              id: 'm1',
              role: CoachMessageRole.user,
              text: 'Why has my weight stalled?',
              createdAt: asked,
            ),
            CoachMessage(
              id: 'm2',
              role: CoachMessageRole.assistant,
              text:
                  'Over the last three weeks you averaged 2,310 kcal against '
                  "an estimated expenditure of 2,290 kcal, so you've been at "
                  'maintenance. Based on your weigh-ins and meal logs since 14 '
                  'September.',
              createdAt: asked.add(const Duration(minutes: 1)),
              blocks: stagingCoachBlocks(
                CoachContextKind.weightTrend,
                messageId: 'm2',
                now: asked,
              ),
            ),
          ],
        ).toFirestore().map((key, value) => MapEntry(key, _stored(value))),
      );
  return CoachRepository(
    firestore: firestore,
    users: users,
    coachChat: stagingCoachChat(
      firestore: firestore,
      users: users,
      uid: signedInUid,
    ),
  );
}

/// `coachChat` played over [firestore] for [uid], as Swift's
/// `MockCoachService` answers: word by word, [wordDelay] apart, with a
/// canned answer for the screen it was asked from.
///
/// Like the function, it refuses without consent (read from [users]),
/// refuses a chat id that does not exist, counts 50 messages a day, and
/// saves both sides of the exchange so the chat list catches up.
CoachChatCall stagingCoachChat({
  required FirebaseFirestore firestore,
  required UserRepository users,
  required String uid,
  DateTime Function()? now,
  Duration wordDelay = const Duration(milliseconds: 30),
}) {
  final clock = now ?? () => DateTime.now().toUtc();
  var sent = 0;
  return (message, {chatId, context}) async* {
    final settings = await users.watchPrivateSettings(uid).first;
    if (settings?.coachConsent != true) {
      throw const CoachException(CoachFailure.consentRequired);
    }
    final chats = firestore.collection('users/$uid/coach_chats');
    final chat = chats.doc(chatId);
    final existing = (await chat.get()).data();
    if (chatId != null && existing == null) {
      throw const CoachException(CoachFailure.failed);
    }
    if (sent == 50) throw const CoachException(CoachFailure.dailyLimitReached);
    sent++;
    final answer = _answers[context?.kind] ?? _answer;
    for (final word in answer.split(' ')) {
      await Future<void>.delayed(wordDelay);
      yield CoachText('$word ');
    }
    final now = clock();
    final time = Timestamp.fromDate(now);
    final reply = '${chat.id}-$sent';
    final blocks = stagingCoachBlocks(
      context?.kind,
      messageId: reply,
      now: now,
      exerciseId: context?.id,
      exerciseName: context?.title,
    );
    for (final block in blocks) {
      await Future<void>.delayed(wordDelay);
      yield CoachBlockShown(block);
    }
    await chat.set({
      CoachChatKeys.id: chat.id,
      CoachChatKeys.title: existing?[CoachChatKeys.title] ?? message,
      CoachChatKeys.createdAt: existing?[CoachChatKeys.createdAt] ?? time,
      CoachChatKeys.updatedAt: time,
      CoachChatKeys.contextKind:
          existing?[CoachChatKeys.contextKind] ?? context?.kind.value,
      CoachChatKeys.messages: [
        ...?existing?[CoachChatKeys.messages] as List<Object?>?,
        for (final (id, role, text, shown) in [
          ('$reply-q', CoachMessageRole.user, message, <CoachBlock>[]),
          (reply, CoachMessageRole.assistant, answer, blocks),
        ])
          {
            CoachMessageKeys.id: id,
            CoachMessageKeys.role: role.value,
            CoachMessageKeys.text: text,
            CoachMessageKeys.createdAt: time,
            if (shown.isNotEmpty)
              CoachMessageKeys.blocks: [
                for (final block in shown) block.toFirestore(),
              ],
          },
      ],
    });
    yield CoachFinished(
      chatId: chat.id,
      messageId: reply,
      text: answer,
      remainingToday: 50 - sent,
      blocks: blocks,
    );
  };
}

/// A model's value as Firestore stores it: a [DateTime] as a [Timestamp].
Object? _stored(Object? value) => switch (value) {
  final DateTime date => Timestamp.fromDate(date),
  final Map<String, Object?> map => map.map(
    (key, value) => MapEntry(key, _stored(value)),
  ),
  final List<Object?> list => list.map(_stored).toList(),
  _ => value,
};

const _answer =
    'Over the last four weeks you trained 3.5 times a week and your bench '
    'press estimated 1RM rose from 95 kg to 101 kg. Based on your 14 '
    'sessions since 7 September.';

/// Canned answers for the screens with most to say; the rest get [_answer].
const Map<CoachContextKind, String> _answers = {
  CoachContextKind.weightTrend:
      'Your trend weight is down 1.2 kg over the last four weeks, about '
      '0.3 kg a week, which is the rate you planned. Based on your 24 '
      'weigh-ins since 18 September.',
  CoachContextKind.nutritionDay:
      "You've eaten 1,640 of your 2,200 kcal and 98 of your 160 g of protein "
      'so far. A chicken breast and a yoghurt would close most of the gap. '
      "Based on today's three meals.",
  CoachContextKind.checkIn:
      'Your expenditure estimate rose by 90 kcal this week as your weight '
      'held steady on more food, so your target went up by the same. Based '
      "on this week's weigh-ins and meal logs.",
  CoachContextKind.expenditure:
      'Your estimated expenditure is 2,480 kcal a day, give or take 120. It '
      'comes from your weight trend and what you logged over the last 28 '
      'days.',
};

/// The blocks the staging coach shows with its answer about [kind], as the
/// function lays them out: every value filled in, on the day of [now].
/// An exercise's chart is about [exerciseId], called [exerciseName].
List<CoachBlock> stagingCoachBlocks(
  CoachContextKind? kind, {
  required String messageId,
  required DateTime now,
  String? exerciseId,
  String? exerciseName,
}) {
  String day(int daysAgo) {
    final date = DateTime(now.year, now.month, now.day - daysAgo);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  var count = 0;
  CoachBlock block(
    String kind,
    String fallback,
    Map<String, Object?> component,
    Map<String, Object?> data,
  ) {
    final surfaceId = '$messageId-${count++}';
    Map<String, Object?> message(String name, Map<String, Object?> body) => {
      'version': 'v0.9',
      name: {'surfaceId': surfaceId, ...body},
    };
    return CoachBlock(
      surfaceId: surfaceId,
      kind: kind,
      asOf: day(0),
      fallback: fallback,
      messages: [
        message('createSurface', {'catalogId': 'compound.coach.v1'}),
        message('updateComponents', {
          'components': [
            {'id': 'root', ...component},
          ],
        }),
        message('updateDataModel', {'path': '/', 'value': data}),
      ],
    );
  }

  Map<String, Object?> bound(String component, List<String> props) => {
    'component': component,
    for (final prop in props) prop: {'path': '/$prop'},
  };

  // Readings along a straight line from [from] to [to] over [days], with
  // a little day-to-day noise.
  List<Map<String, Object?>> line(
    double from,
    double to,
    int days, {
    int every = 1,
    double noise = 0,
    int digits = 1,
  }) => [
    for (var n = days; n >= 0; n -= every)
      {
        'x': day(n),
        'y': double.parse(
          (from +
                  (to - from) * (days - n) / days +
                  noise * ((n * 7919) % 11 - 5) / 5)
              .toStringAsFixed(digits),
        ),
      },
  ];

  Map<String, Object?> stat(String key, num? value, String unit) => {
    'key': key,
    'value': value,
    'unit': unit,
  };

  CoachBlock actions(String fallback, List<Map<String, Object?>> list) => block(
    'actions',
    fallback,
    bound('Actions', ['actions']),
    {'actions': list},
  );

  CoachBlock followUps(List<String> questions) => block(
    'follow_ups',
    'Suggested questions: ${questions.join(' / ')}',
    bound('FollowUps', ['questions']),
    {'questions': questions},
  );

  return switch (kind) {
    CoachContextKind.weightTrend => [
      block(
        'trend_chart',
        'Weight trend, ${day(56)} to ${day(0)}: 73.1 → 72.3 kg.',
        {
          ...bound('TrendChart', ['points', 'trend', 'unit']),
          'metric': 'weight',
        },
        {
          'points': line(73.1, 72.3, 56, every: 2, noise: 0.4),
          'trend': line(73.1, 72.3, 56, every: 7, digits: 2),
          'unit': 'kg',
        },
      ),
      actions('You can: Log weight; Open weight.', [
        {'kind': 'log_weight'},
        {'kind': 'open_metric', 'metric': 'weight'},
      ]),
      followUps([
        'How much should I eat to lose faster?',
        'Is my protein high enough?',
      ]),
    ],
    CoachContextKind.nutritionDay => [
      block(
        'target_bars',
        'Food on ${day(0)}: 1,640 of 2,200 kcal, 98 of 160 g protein, 180 '
            'of 240 g carbs, 52 of 70 g fat.',
        bound('TargetBars', ['rows', 'day']),
        {
          'day': day(0),
          'rows': [
            for (final (nutrient, value, target, unit) in [
              ('calories', 1640, 2200, 'kcal'),
              ('protein', 98, 160, 'g'),
              ('carbs', 180, 240, 'g'),
              ('fat', 52, 70, 'g'),
            ])
              {
                'nutrient': nutrient,
                'value': value,
                'target': target,
                'unit': unit,
              },
          ],
        },
      ),
      actions('You can: Log a meal.', [
        {'kind': 'log_meal'},
      ]),
    ],
    CoachContextKind.checkIn => [
      block(
        'stat_row',
        'Expenditure: 2,480 kcal; Calorie target today: 2,200 kcal; Weekly '
            'change: −0.3 kg/wk.',
        bound('StatRow', ['stats']),
        {
          'stats': [
            stat('expenditure', 2480, 'kcal'),
            stat('calorie_target', 2200, 'kcal'),
            stat('weight_rate_per_week', -0.3, 'kg_per_week'),
          ],
        },
      ),
      actions('You can: Open the weekly check-in; Open the diet plan.', [
        {'kind': 'open_check_in'},
        {'kind': 'open_diet_plan'},
      ]),
    ],
    CoachContextKind.expenditure => [
      block(
        'trend_chart',
        'Expenditure, ${day(28)} to ${day(0)}: 2,390 → 2,480 kcal.',
        {
          ...bound('TrendChart', ['points', 'unit']),
          'metric': 'expenditure',
        },
        {'points': line(2390, 2480, 28, noise: 15, digits: 0), 'unit': 'kcal'},
      ),
    ],
    CoachContextKind.exercise when exerciseId != null => [
      block(
        'trend_chart',
        'Estimated 1RM, ${exerciseName ?? exerciseId}, ${day(84)} to '
            '${day(0)}: 95 → 101 kg.',
        {
          ...bound('TrendChart', ['points', 'unit', 'exerciseName']),
          'metric': 'exercise_e1rm',
        },
        {
          'points': line(95, 101, 84, every: 4, noise: 0.8),
          'unit': 'kg',
          'exerciseName': exerciseName,
        },
      ),
      actions('You can: Open ${exerciseName ?? exerciseId}; Start a workout.', [
        {
          'kind': 'open_exercise',
          'exerciseId': exerciseId,
          'exerciseName': exerciseName,
        },
        {'kind': 'start_workout'},
      ]),
    ],
    _ => [
      block(
        'stat_row',
        'Calories today: 1,640 kcal; Protein today: 98 g; Steps, 30-day '
            'average: 8,420 steps.',
        bound('StatRow', ['stats']),
        {
          'stats': [
            stat('today_calories', 1640, 'kcal'),
            stat('today_protein', 98, 'g'),
            stat('steps_average', 8420, 'steps'),
          ],
        },
      ),
      followUps([
        'What should I train next?',
        'How is my bench press progressing?',
      ]),
    ],
  };
}
