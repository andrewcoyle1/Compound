/// What the `strava*` callables and Strava's upload API answer, and the
/// failures they come to (Swift `StravaAthlete.swift`,
/// `StravaUploadStatus.swift`, `StravaError`).
library;

import 'package:compound_models/compound_models.dart' show readInt;
import 'package:flutter/foundation.dart' show immutable;

/// The Strava account a Compound account is connected to, as the server
/// stored it at connect (`stravaAthlete` in `functions/lib.js`).
@immutable
class const StravaAthlete({
  /// Strava's athlete id.
  required final int id,

  /// First name; the server stores a missing one as "".
  final String? firstname,

  /// Last name; the server stores a missing one as "".
  final String? lastname,

  /// The avatar's URL.
  final String? profile,
}) {
  /// Creates a [StravaAthlete].
  this;

  /// Reads the server's map; throws on anything else.
  factory fromJson(Map<Object?, Object?> json) => StravaAthlete(
    id: readInt(json['id']),
    firstname: json['firstname'] as String?,
    lastname: json['lastname'] as String?,
    profile: json['profile'] as String?,
  );

  /// The map [StravaAthlete.fromJson] reads, as Swift encodes it.
  Map<String, Object?> toJson() => {
    'id': id,
    'firstname': ?firstname,
    'lastname': ?lastname,
    'profile': ?profile,
  };

  /// "First Last", leaving out whichever is missing or empty.
  String get name => [
    firstname,
    lastname,
  ].whereType<String>().where((part) => part.isNotEmpty).join(' ');

  @override
  bool operator ==(Object other) =>
      other is StravaAthlete &&
      other.id == id &&
      other.firstname == firstname &&
      other.lastname == lastname &&
      other.profile == profile;

  @override
  int get hashCode => Object.hash(id, firstname, lastname, profile);
}

/// A short-lived access token the server hands out; the refresh token never
/// leaves it.
class const StravaAccessToken({
  /// The bearer token for Strava's API.
  required final String accessToken,

  /// When it expires, in seconds since the epoch.
  required final int expiresAt,
}) {
  /// Creates a [StravaAccessToken].
  this;

  /// Reads `{access_token, expires_at}`.
  factory fromJson(Map<Object?, Object?> json) => StravaAccessToken(
    accessToken: json['access_token']! as String,
    expiresAt: readInt(json['expires_at']),
  );
}

/// What `stravaConnect` answers: a first token and the athlete.
class const StravaConnectResult({
  /// The token to use straight away.
  required final StravaAccessToken token,

  /// The athlete now connected.
  required final StravaAthlete athlete,
}) {
  /// Creates a [StravaConnectResult].
  this;

  /// Reads `{access_token, expires_at, athlete}`.
  factory fromJson(Map<Object?, Object?> json) => StravaConnectResult(
    token: StravaAccessToken.fromJson(json),
    athlete: StravaAthlete.fromJson(json['athlete']! as Map<Object?, Object?>),
  );
}

/// What `POST /uploads` and `GET /uploads/{id}` answer. Processing is
/// asynchronous: the activity id appears once Strava has made the
/// activity, or [error] says why it did not.
@immutable
class const StravaUploadStatus({
  /// The upload's id, to poll.
  required final int id,

  /// Why Strava did not make an activity, when it did not.
  final String? error,

  /// The activity Strava made.
  final int? activityId,
}) {
  /// Creates a [StravaUploadStatus].
  this;

  /// Reads Strava's JSON; other keys (`id_str`, `status`, …) are ignored.
  factory fromJson(Map<Object?, Object?> json) => StravaUploadStatus(
    id: readInt(json['id']),
    error: json['error'] as String?,
    activityId: json['activity_id'] == null
        ? null
        : readInt(json['activity_id']),
  );

  /// The activity an upload duplicates. Strava refuses a second upload with
  /// the same `external_id` ("… duplicate of activity 21234316"), which is
  /// the first one succeeding.
  int? get duplicateActivityId {
    final match = RegExp(r'duplicate of activity (\d+)')
        .firstMatch(error ?? '');
    return match == null ? null : int.parse(match.group(1)!);
  }

  @override
  bool operator ==(Object other) =>
      other is StravaUploadStatus &&
      other.id == id &&
      other.error == error &&
      other.activityId == activityId;

  @override
  int get hashCode => Object.hash(id, error, activityId);
}

/// Why a Strava call failed (Swift `StravaError`). The words are the app's
/// to choose; Swift's are on each value.
enum StravaFailure {
  /// Strava's redirect carried no code: the athlete cancelled or refused.
  /// "No authorization code was returned from Strava."
  missingAuthCode,

  /// The athlete unticked the upload permission on Strava's consent page
  /// (or `stravaConnect` answered `failed-precondition`). "Allow Compound to
  /// upload your activities to connect Strava."
  missingUploadPermission,

  /// This account is not connected (`not-found`), or no longer is. "Not
  /// connected to Strava."
  notConnected,

  /// Strava refused the token: the athlete revoked access (a 401, or
  /// `permission-denied` from a callable). Handled inside the repository,
  /// which reports it as [notConnected].
  authorizationRevoked,

  /// Strava answered an upload or edit with this [StravaException.status].
  /// "Strava did not accept the upload (status)."
  uploadFailed,

  /// Over Strava's request limit (200 every 15 minutes, 2,000 a day by
  /// default, shared by every user of the app). "Strava is busy. Your
  /// workouts will upload later."
  rateLimited,

  /// Strava took the upload and could not make an activity of it, for
  /// [StravaException.reason]. "Strava could not process the workout."
  processingFailed,

  /// The network, the function or Strava failed in any other way; worth
  /// trying again later.
  unavailable,
}

/// A failed Strava call.
class const StravaException(
  /// What went wrong.
  final StravaFailure failure, {

  /// The HTTP status, for [StravaFailure.uploadFailed].
  final int? status,

  /// Strava's reason, for [StravaFailure.processingFailed].
  final String? reason,

  /// The underlying error, when there was one.
  final Object? cause,
}) implements Exception {
  /// Creates a [StravaException].
  this;

  @override
  String toString() =>
      'StravaException(${failure.name}'
      '${status == null ? '' : ', $status'}'
      '${reason == null ? '' : ', $reason'}'
      '${cause == null ? '' : ', $cause'})';
}
