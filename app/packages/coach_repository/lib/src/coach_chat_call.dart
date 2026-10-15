import 'package:cloud_functions/cloud_functions.dart';
import 'package:compound_models/compound_models.dart';

/// The region of `coachChat`, beside the Firestore data it reads. The app
/// passes `FirebaseFunctions.instanceFor(region: coachFunctionsRegion)` to
/// [firebaseCoachChat], on an app with App Check activated.
const coachFunctionsRegion = 'europe-west4';

/// Where the coach was opened from (Swift `CoachContext.Kind`). The server
/// starts from the right data; the chat screen picks its suggested
/// questions.
enum CoachContextKind {
  /// `today`.
  today('today'),

  /// `weight_trend`.
  weightTrend('weight_trend'),

  /// `exercise`.
  exercise('exercise'),

  /// `session`.
  session('session'),

  /// `check_in`.
  checkIn('check_in'),

  /// `nutrition_day`.
  nutritionDay('nutrition_day'),

  /// `weekly_review`.
  weeklyReview('weekly_review'),

  /// `mesocycle`.
  mesocycle('mesocycle'),

  /// `expenditure`.
  expenditure('expenditure'),

  /// `muscle_group`.
  muscleGroup('muscle_group');

  new(this.value);

  /// The value sent, and stored as a chat's `context_kind`.
  final String value;
}

/// Where the coach was opened from, and what about (Swift `CoachContext`).
class const CoachContext({
  /// The kind of screen.
  required final CoachContextKind kind,

  /// The exercise template, session or muscle the screen is about.
  final String? id,

  /// The day, as `yyyy-MM-dd`, for a day's nutrition.
  final String? date,

  /// What the screen shows, for the chat's header, such as "Barbell Bench
  /// Press". Not sent.
  final String? title,
}) {
  /// Creates a [CoachContext].
  this;

  /// Opened from Today.
  static const today = CoachContext(kind: CoachContextKind.today);
}

/// One step of an answer as it streams (Swift `CoachStreamEvent`).
sealed class CoachStreamEvent {
  /// Creates a [CoachStreamEvent].
  const new();
}

/// More of the answer's text, to append to what has arrived.
final class const CoachText(
  /// The new text.
  final String text,
) extends CoachStreamEvent {
  /// Creates a [CoachText].
  this;
}

/// The answer is complete and saved: the last event of a reply.
///
/// [text] is the whole answer; show it in place of what streamed, because
/// a reply can also arrive whole, with no [CoachText] before it.
final class const CoachFinished({
  /// The chat it was saved in: new when no chat id was sent.
  required final String chatId,

  /// The saved answer's id.
  required final String messageId,

  /// The whole answer.
  required final String text,

  /// What is left of today's 50 messages.
  required final int remainingToday,
}) extends CoachStreamEvent {
  /// Creates a [CoachFinished].
  this;
}

/// Why the coach could not answer (Swift `CoachError`), in the terms the
/// chat screen acts on.
enum CoachFailure {
  /// No agreement to share data with the provider yet, or it was withdrawn.
  consentRequired,

  /// The coach is part of Premium.
  premiumRequired,

  /// Today's 50 messages are used up; none are left.
  dailyLimitReached,

  /// More than 5 messages in a minute. Swift reports this as
  /// [dailyLimitReached]; the function tells them apart.
  tooManyAtOnce,

  /// Not reachable, timed out or failed on the server: try again.
  unavailable,

  /// Refused for another reason, such as a chat that no longer exists.
  failed,
}

/// The coach could not answer.
class const CoachException(
  /// Why.
  final CoachFailure failure, [

  /// The error behind it, if any.
  final Object? cause,
]) implements Exception {
  /// Creates a [CoachException].
  this;

  @override
  String toString() => 'CoachException(${failure.name}, $cause)';
}

/// Sends one [message] and streams the answer (Swift `CoachService`). A
/// null [chatId] starts a new chat. The stream fails with a
/// [CoachException].
typedef CoachChatCall = Stream<CoachStreamEvent> Function(
  String message, {
  String? chatId,
  CoachContext? context,
});

/// [CoachChatCall] on the `coachChat` callable (Swift
/// `ProductionCoachService`), allowed 120 seconds because its tools read
/// history before the model answers.
///
/// The request is `{chatId?, message, context?: {kind, id?, date?}}`, with
/// absent values left out as Swift's encoder leaves them.
///
/// cloud_functions 6.5 streams, but drops a refusal's code: on Android the
/// stream just ends, and on iOS every error arrives as `unknown`. So when
/// the stream ends without a result, or fails without a code, the message
/// is sent once more without streaming, which does carry the code. The
/// function refuses for consent, premium and quota before it counts or
/// generates anything, so that second call costs nothing then.
// ponytail: if the stream drops after the server saved the reply, the
// retry answers again and the chat holds the exchange twice. Remove the
// fallback once FlutterFire's stream reports FirebaseFunctionsException.
CoachChatCall firebaseCoachChat(FirebaseFunctions functions) {
  final callable = functions.httpsCallable(
    'coachChat',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
  );
  return (message, {chatId, context}) async* {
    final request = <String, Object?>{
      'chatId': ?chatId,
      'message': message,
      if (context != null)
        'context': {
          'kind': context.kind.value,
          'id': ?context.id,
          'date': ?context.date,
        },
    };
    try {
      await for (final response in callable.stream<Object?, Object?>(request)) {
        switch (response) {
          case Chunk(:final partialData):
            yield CoachText((partialData! as Map)['text']! as String);
          case Result(:final result):
            yield _finished(result.data);
            return;
        }
      }
    } on FirebaseFunctionsException catch (error) {
      if (error.code != 'unknown') throw CoachException(_failure(error), error);
    } on Object {
      // No code to go on: ask again below.
    }
    try {
      yield _finished((await callable.call<Object?>(request)).data);
    } on Object catch (error) {
      throw CoachException(_failure(error), error);
    }
  };
}

CoachFinished _finished(Object? data) {
  final result = data! as Map;
  return CoachFinished(
    chatId: result['chatId']! as String,
    messageId: result['messageId']! as String,
    text: result['text']! as String,
    remainingToday: readInt(result['remainingToday']),
  );
}

/// The function's refusals as the app's (`ProductionCoachService
/// .coachError`): a reason in the error's details tells consent, premium
/// and the burst limit apart. Anything that is not a functions error, an
/// unreadable answer included, is [CoachFailure.unavailable].
CoachFailure _failure(Object error) {
  if (error is! FirebaseFunctionsException) return CoachFailure.unavailable;
  final reason = switch (error.details) {
    {'reason': final String reason} => reason,
    _ => null,
  };
  return switch (error.code) {
    'failed-precondition' when reason == 'consent' =>
      CoachFailure.consentRequired,
    'permission-denied' when reason == 'premium' =>
      CoachFailure.premiumRequired,
    'resource-exhausted' when reason == 'burst' => CoachFailure.tooManyAtOnce,
    'resource-exhausted' => CoachFailure.dailyLimitReached,
    'unavailable' ||
    'deadline-exceeded' ||
    'internal' ||
    'unknown' ||
    'cancelled' => CoachFailure.unavailable,
    _ => CoachFailure.failed,
  };
}
