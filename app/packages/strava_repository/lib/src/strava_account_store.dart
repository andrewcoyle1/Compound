/// What the device keeps per Compound account about Strava, across launches
/// (Swift keeps the same in `UserDefaults`: `strava_athlete_<uid>`,
/// `strava_pending_uploads_<uid>`, `strava_offer_answered_<uid>`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:strava_repository/src/strava_models.dart';

/// One account's Strava state on this device.
class const StravaAccountState({
  /// The athlete last known to be connected, so a launch knows before the
  /// server answers.
  final StravaAthlete? athlete,

  /// Sessions waiting to go to Strava, oldest first.
  final List<String> pendingSessionIds = const [],

  /// Whether the athlete has answered the offer to connect (`StravaOffer`).
  final bool offerAnswered = false,
}) {
  /// Creates a [StravaAccountState].
  this;

  /// Reads [toJson]'s output; throws a [FormatException] for anything else.
  factory fromJson(Map<String, Object?> json) {
    try {
      return StravaAccountState(
        athlete: switch (json['athlete']) {
          final Map<String, Object?> athlete => StravaAthlete.fromJson(athlete),
          _ => null,
        },
        pendingSessionIds: List<String>.from(
          json['pending_session_ids']! as List,
        ),
        offerAnswered: json['offer_answered']! as bool,
      );
    } on Object catch (error) {
      throw FormatException('Not a Strava account state', '$error');
    }
  }

  /// Plain JSON.
  Map<String, Object?> toJson() => {
    'athlete': ?athlete?.toJson(),
    'pending_session_ids': pendingSessionIds,
    'offer_answered': offerAnswered,
  };

  /// A copy with the given values replaced; [clearAthlete] forgets it.
  StravaAccountState copyWith({
    StravaAthlete? athlete,
    bool clearAthlete = false,
    List<String>? pendingSessionIds,
    bool? offerAnswered,
  }) => StravaAccountState(
    athlete: clearAthlete ? null : athlete ?? this.athlete,
    pendingSessionIds: pendingSessionIds ?? this.pendingSessionIds,
    offerAnswered: offerAnswered ?? this.offerAnswered,
  );
}

/// Where each account's [StravaAccountState] is kept.
abstract interface class StravaAccountStore {
  /// [uid]'s state; the default when none is kept.
  Future<StravaAccountState> load(String uid);

  /// Keeps [state] as [uid]'s.
  Future<void> save(String uid, StravaAccountState state);
}

/// [StravaAccountStore] in memory, for the staging flavor and tests. Each
/// load is a copy, as a file's is.
class InMemoryStravaAccountStore implements StravaAccountStore {
  final _json = <String, String>{};

  @override
  Future<StravaAccountState> load(String uid) async => switch (_json[uid]) {
    final json? => StravaAccountState.fromJson(
      jsonDecode(json) as Map<String, Object?>,
    ),
    null => const StravaAccountState(),
  };

  @override
  Future<void> save(String uid, StravaAccountState state) async =>
      _json[uid] = jsonEncode(state.toJson());
}

/// [StravaAccountStore] as one JSON file per account in a directory (the
/// app passes one in its support directory). Each is written whole to a
/// temporary file and renamed over the last, so a kill mid-write leaves the
/// previous state rather than half of one. A file this build cannot read
/// reads as the default: the queue is rebuilt from past workouts by a
/// backfill, and the connection from the server.
class FileStravaAccountStore implements StravaAccountStore {
  /// Keeps the files in [_directory].
  new(this._directory);

  final Directory _directory;

  File _file(String uid) =>
      File('${_directory.path}/strava_${Uri.encodeComponent(uid)}.json');

  @override
  Future<StravaAccountState> load(String uid) async {
    final file = _file(uid);
    if (!file.existsSync()) return const StravaAccountState();
    try {
      return switch (jsonDecode(await file.readAsString())) {
        final Map<String, Object?> json => StravaAccountState.fromJson(json),
        final other => throw FormatException('Not an object', other),
      };
    } on FormatException {
      return const StravaAccountState();
    }
  }

  @override
  Future<void> save(String uid, StravaAccountState state) async {
    final file = _file(uid);
    final temporary = File('${file.path}.tmp');
    await _directory.create(recursive: true);
    await temporary.writeAsString(jsonEncode(state.toJson()), flush: true);
    await temporary.rename(file.path);
  }
}
