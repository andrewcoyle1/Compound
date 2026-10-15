/// The pure rules the Swift app's social code applies around its reads and
/// writes: handles, invite codes, the following queries' bounds, display
/// names and who hears about a comment.
library;

import 'dart:math';

import 'package:compound_models/compound_models.dart';

/// Why a handle is or is not valid (Swift `Username.Validation`). The words
/// for each live in the app's ARB strings.
enum UsernameValidation {
  /// Valid.
  valid,

  /// Fewer than [Username.minLength] characters.
  tooShort,

  /// More than [Username.maxLength] characters.
  tooLong,

  /// Something other than `a-z`, `0-9`, `_` and `.`.
  invalidCharacters,

  /// Starts or ends with a dot.
  edgeDot,
}

/// The rules for a handle (Swift `Username.swift`), which `firestore.rules`
/// repeats for the reservation's document id.
abstract final class Username {
  /// The shortest handle.
  static const minLength = 3;

  /// The longest handle.
  static const maxLength = 20;

  static final _allowed = RegExp(r'^[a-z0-9_.]*$');

  /// What the user typed as it would be stored: trimmed, without a leading
  /// `@`, lower case (`Username.swift:38-42`).
  static String normalised(String raw) {
    final text = raw.trim();
    return (text.startsWith('@') ? text.substring(1) : text).toLowerCase();
  }

  /// Checks an already-normalised handle, in Swift's order
  /// (`Username.swift:45-51`).
  static UsernameValidation validate(String handle) {
    if (!_allowed.hasMatch(handle)) return UsernameValidation.invalidCharacters;
    if (handle.length < minLength) return UsernameValidation.tooShort;
    if (handle.length > maxLength) return UsernameValidation.tooLong;
    if (handle.startsWith('.') || handle.endsWith('.')) {
      return UsernameValidation.edgeDot;
    }
    return UsernameValidation.valid;
  }

  /// Whether [handle] is valid.
  static bool isValid(String handle) =>
      validate(handle) == UsernameValidation.valid;

  /// How a people search runs (`Username.swift:59-67`): a query starting
  /// with `@` is only a handle; any other is a name, and also a handle
  /// prefix when it could start one.
  static ({String? name, String? handlePrefix}) searchRoute(String query) {
    final trimmed = query.trim();
    final prefix = normalised(trimmed);
    final couldBeHandle =
        prefix.isNotEmpty &&
        prefix.length <= maxLength &&
        _allowed.hasMatch(prefix);
    return (
      name: trimmed.startsWith('@') || trimmed.isEmpty ? null : trimmed,
      handlePrefix: couldBeHandle ? prefix : null,
    );
  }
}

/// Invite codes (Swift `InviteCode`): eight characters with no 0/O or
/// 1/I/L, mirrored in `functions/lib.js` and `firestore.rules`.
abstract final class InviteCode {
  /// The characters a code is drawn from.
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// A code's length.
  static const length = 8;

  /// A random code; [random] defaults to a secure generator.
  static String random([Random? random]) {
    final source = random ?? Random.secure();
    return String.fromCharCodes([
      for (var i = 0; i < length; i++)
        alphabet.codeUnitAt(source.nextInt(alphabet.length)),
    ]);
  }

  /// Upper-cased with spaces and dashes dropped, or null when what is left
  /// is not a code, so "push 2345" and "push-2345" work
  /// (`InviteModel.swift:66-70`).
  static String? normalised(String raw) {
    final code = raw.toUpperCase().replaceAll(RegExp('[ -]'), '');
    return code.length == length && code.split('').every(alphabet.contains)
        ? code
        : null;
  }
}

/// The bounds on the two listeners over the people a user follows
/// (`FollowingQueries.swift`), which decide most of what a launch costs in
/// reads.
abstract final class FollowingQueries {
  /// Firestore refuses an `in` filter of more than 30 values; past that the
  /// listener never attached, so only the first 30 are used.
  static const maxInValues = 30;

  /// The feed needs followed users' recent sessions, not their history.
  static const sessionLimit = 200;

  /// Unique [ids], in order, at most [maxInValues] of them.
  static List<String> cappedIds(Iterable<String> ids) =>
      ids.toSet().take(maxInValues).toList();
}

/// The first name Swift shows (`UserModel.firstNameCalculated`): the one
/// the user typed, else their account's, ignoring empty ones.
String? firstNameOf(UserModel user) =>
    _nonEmpty(user.submittedFirstName) ?? _nonEmpty(user.firstName);

/// The full name Swift shows (`UserModel.fullNameCalculated`).
String? fullNameOf(UserModel user) {
  final names = [firstNameOf(user), _lastNameOf(user)].nonNulls;
  return names.isEmpty ? null : names.join(' ');
}

String? _lastNameOf(UserModel user) =>
    _nonEmpty(user.submittedLastName) ?? _nonEmpty(user.lastName);

String? _nonEmpty(String? text) => text == null || text.isEmpty ? null : text;

/// The picture Swift shows (`UserModel.profileImageNameCalculated`): the
/// uploaded one, else the account's.
String? profileImageOf(UserModel user) =>
    user.submittedProfileImage ?? user.photoUrl;

/// The notifications [comment] writes, keyed by recipient, as
/// `WorkoutSessionComment.activityNotifications` builds them
/// (`WorkoutSessionComment.swift:54-93`).
///
/// The session's author and the parent comment's author hear of a comment;
/// anyone tagged and not already told gets a mention. The writer is told
/// nothing and nobody is told twice. The parent's author hears it as a
/// reply unless they wrote the session.
List<(String, ActivityNotificationModel)> commentNotifications(
  WorkoutSessionComment comment, {
  String? parentAuthorId,
}) {
  final commented = {comment.sessionAuthorId, ?parentAuthorId}
    ..remove(comment.authorId);
  final mentioned = comment.mentionedUserIds.toSet()
    ..removeAll(commented)
    ..remove(comment.authorId);
  ActivityNotificationModel notification(ActivityType type, {bool? reply}) =>
      ActivityNotificationModel(
        id: '${type.value}_${comment.id}',
        type: type,
        actorId: comment.authorId,
        actorName: comment.authorName ?? 'Someone',
        actorImageUrl: comment.authorImageUrl,
        sessionId: comment.sessionId,
        sessionAuthorId: comment.sessionAuthorId,
        commentText: comment.text,
        dateCreated: comment.dateCreated,
        isReply: reply ?? false,
      );
  return [
    for (final userId in commented.toList()..sort())
      (
        userId,
        notification(
          ActivityType.comment,
          reply:
              comment.parentId != null &&
              userId == parentAuthorId &&
              userId != comment.sessionAuthorId,
        ),
      ),
    for (final userId in mentioned.toList()..sort())
      (userId, notification(ActivityType.mention)),
  ];
}
