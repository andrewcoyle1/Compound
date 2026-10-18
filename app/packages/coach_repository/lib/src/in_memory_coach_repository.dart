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
    final time = Timestamp.fromDate(clock());
    final reply = '${chat.id}-$sent';
    await chat.set({
      CoachChatKeys.id: chat.id,
      CoachChatKeys.title: existing?[CoachChatKeys.title] ?? message,
      CoachChatKeys.createdAt: existing?[CoachChatKeys.createdAt] ?? time,
      CoachChatKeys.updatedAt: time,
      CoachChatKeys.contextKind:
          existing?[CoachChatKeys.contextKind] ?? context?.kind.value,
      CoachChatKeys.messages: [
        ...?existing?[CoachChatKeys.messages] as List<Object?>?,
        for (final (id, role, text) in [
          ('$reply-q', CoachMessageRole.user, message),
          (reply, CoachMessageRole.assistant, answer),
        ])
          {
            CoachMessageKeys.id: id,
            CoachMessageKeys.role: role.value,
            CoachMessageKeys.text: text,
            CoachMessageKeys.createdAt: time,
          },
      ],
    });
    yield CoachFinished(
      chatId: chat.id,
      messageId: reply,
      text: answer,
      remainingToday: 50 - sent,
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
