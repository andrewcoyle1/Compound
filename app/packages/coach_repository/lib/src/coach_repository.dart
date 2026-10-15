import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coach_repository/src/coach_chat_call.dart';
import 'package:compound_models/compound_models.dart';
import 'package:user_repository/user_repository.dart';

/// Called with a chat's path when it cannot be decoded and is skipped.
typedef CoachDecodeErrorHandler = void Function(
  String path,
  Object error,
  StackTrace stackTrace,
);

/// The AI coach (Swift `CoachManager`): a read-only chat about the user's
/// own data, answered by the `coachChat` Cloud Function, which also saves
/// every exchange in `users/{uid}/coach_chats`. The app only reads and
/// deletes those chats.
///
/// Premium is the caller's to check first (`purchases_repository`); the
/// function checks it again.
///
/// The staging flavor runs this same class over an in-memory Firestore
/// (`inMemoryCoachRepository`).
class CoachRepository {
  /// Creates a [CoachRepository]. [now] stamps when consent is given.
  new({
    required this._firestore,
    required this._users,
    required this._coachChat,
    DateTime Function()? now,
    this._onWriteError = logWriteError,
    this._onDecodeError = _log,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  final FirebaseFirestore _firestore;
  final UserRepository _users;
  final CoachChatCall _coachChat;
  final DateTime Function() _now;
  final WriteErrorReporter _onWriteError;
  final CoachDecodeErrorHandler _onDecodeError;

  /// [uid]'s saved chats, newest first, re-emitted on every change. A chat
  /// that does not decode is skipped and reported, as Swift's sync engine
  /// drops it.
  Stream<List<CoachChat>> watchChats(String uid) => _chats(uid).snapshots().map(
    (snapshot) =>
        [for (final document in snapshot.docs) ?_decode(document)]
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );

  /// Deletes [uid]'s chat [chatId]. Completes once Firestore has the delete
  /// locally ([writeLocally]).
  Future<void> deleteChat(String uid, String chatId) =>
      _delete(_chats(uid).doc(chatId));

  /// Whether [uid] has agreed to share their data with the provider
  /// (`coach_consent == true` in their private settings).
  Stream<bool> watchConsent(String uid) => _users
      .watchPrivateSettings(uid)
      .map((settings) => settings?.coachConsent ?? false);

  /// Records [uid]'s consent, and when it was given.
  Future<void> giveConsent(String uid) => _users.mergePrivateSettings(
    uid,
    PrivateUserSettings(coachConsent: true, coachConsentAt: _now()),
  );

  /// Stops the coach reading anything, then deletes every chat. The flag
  /// goes first, as in Swift: a chat that failed to delete is worth less
  /// than consent that failed to be withdrawn. It is written `false`, not
  /// cleared, because the settings merge.
  ///
  /// Reading the chats waits for Firestore, which answers from its cache
  /// once it knows it is offline.
  Future<void> withdrawConsent(String uid) async {
    await _users.mergePrivateSettings(
      uid,
      const PrivateUserSettings(coachConsent: false),
    );
    for (final chat in (await _chats(uid).get()).docs) {
      await _delete(chat.reference);
    }
  }

  /// Sends [message] and streams the answer; a null [chatId] starts a new
  /// chat. The function saves both sides, so [watchChats] catches up on its
  /// own. [CoachFinished.remainingToday] is what is left of the day's
  /// messages.
  ///
  /// The stream fails with a [CoachException]. On
  /// [CoachFailure.dailyLimitReached] none are left.
  Stream<CoachStreamEvent> send(
    String message, {
    String? chatId,
    CoachContext? context,
  }) => _coachChat(message, chatId: chatId, context: context);

  CollectionReference<Map<String, dynamic>> _chats(String uid) =>
      _firestore.collection('users').doc(uid).collection('coach_chats');

  Future<void> _delete(DocumentReference<Map<String, dynamic>> document) =>
      writeLocally(document.path, document.delete, _onWriteError);

  CoachChat? _decode(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    try {
      return CoachChat.fromFirestore(_fromFirestore(document.data()));
    } on Object catch (error, stackTrace) {
      _onDecodeError(document.reference.path, error, stackTrace);
      return null;
    }
  }

  static void _log(String path, Object error, StackTrace stackTrace) =>
      developer.log(
        'Could not read $path: it does not decode',
        name: 'coach_repository',
        error: error,
        stackTrace: stackTrace,
      );
}

/// Firestore's values as the models read them, at any depth: a [Timestamp]
/// becomes a UTC [DateTime].
Map<String, Object?> _fromFirestore(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _value(value)));

Object? _value(Object? value) => switch (value) {
  final Timestamp timestamp => timestamp.toDate().toUtc(),
  final Map<String, Object?> map => _fromFirestore(map),
  final List<Object?> list => list.map(_value).toList(),
  _ => value,
};
