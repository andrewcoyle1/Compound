/// The workout under way, kept on the device while training, as the Swift
/// app keeps it (`WorkoutSessionManager.activeSession`, its screen state and
/// the rest and pause `SharedWorkoutStorage` holds): nothing reaches
/// Firestore until the workout is finished.
library;

import 'dart:convert';
import 'dart:io';

import 'package:compound_models/compound_models.dart' as m;
import 'package:training_rules/training_rules.dart' as r;

/// Where a finished workout kept on the device stands with the server.
enum SavedFinish {
  /// Saved on this device and handed to Health and Strava; kept until the
  /// server has it, and not opened in the tracker meanwhile.
  awaitingServer,

  /// The server refused it. The tracker offers it again; finishing it
  /// again does not send it to Health or Strava a second time.
  refused,
}

/// Everything needed to carry on with a workout after the app is killed.
class const ActiveSessionState({
  /// The session, as it would be saved.
  required final m.WorkoutSessionModel session,

  /// The exercise opened on the card.
  final String? cardExerciseId,

  /// When the running rest ends; `null` with none running.
  final DateTime? restEnd,

  /// When the last rest began, kept after it runs out so its row reads
  /// Ready until the next set.
  final DateTime? restStartedAt,

  /// When the workout was paused; `null` while it runs.
  final DateTime? pausedAt,

  /// Seconds spent paused before [pausedAt].
  final double pausedSeconds = 0,

  /// Rests set by hand on a row, by set id.
  final Map<String, int> customRestSeconds = const {},

  /// What was filled in for the user before they touched anything, by set
  /// id: a set still holding it may be re-suggested live.
  final Map<String, r.SuggestedSet> progressionBaseline = const {},

  /// Exercise template ids whose progression note was dismissed.
  final Set<String> acknowledgedNoteTemplateIds = const {},

  /// Up to when the screen has seen the logged sets.
  final DateTime? lastSeenSetCompletion,

  /// For a finished workout saved before, where it stands with the server;
  /// `null` for one never saved.
  final SavedFinish? saved,
}) {
  /// Reads [toJson]'s output; throws a [FormatException] for anything else.
  factory fromJson(Map<String, Object?> json) {
    try {
      if (json['version'] != version) {
        throw FormatException('Unknown version', json['version']);
      }
      DateTime? date(String key) => switch (json[key]) {
        null => null,
        final Map<String, Object?> tagged =>
          m.taggedJsonToFirestore({'d': tagged})['d']! as DateTime,
        final other => throw FormatException('Not a date', other),
      };
      return ActiveSessionState(
        session: m.WorkoutSessionModel.fromFirestore(
          m.taggedJsonToFirestore(json['session']! as Map<String, Object?>),
        ),
        cardExerciseId: json['card_exercise_id'] as String?,
        restEnd: date('rest_end'),
        restStartedAt: date('rest_started_at'),
        pausedAt: date('paused_at'),
        pausedSeconds: (json['paused_seconds']! as num).toDouble(),
        customRestSeconds: Map<String, int>.from(
          json['custom_rest_seconds']! as Map,
        ),
        progressionBaseline: {
          for (final MapEntry(:key, :value)
              in (json['progression_baseline']! as Map<String, Object?>)
                  .entries)
            key: _baseline(value! as Map<String, Object?>),
        },
        acknowledgedNoteTemplateIds: Set<String>.from(
          json['acknowledged_note_template_ids']! as List,
        ),
        lastSeenSetCompletion: date('last_seen_set_completion'),
        saved: switch (json['saved']) {
          null => null,
          final String name => SavedFinish.values.byName(name),
          final other => throw FormatException('Not a saved state', other),
        },
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      // A cast or a missing field: the file is not one this build wrote.
      throw FormatException('Not an active session', '$error');
    }
  }

  /// The current format of [toJson].
  static const version = 1;

  /// Plain JSON, dates tagged as the Firestore contract tags them.
  Map<String, Object?> toJson() => {
    'version': version,
    'session': m.firestoreToTaggedJson(session.toFirestore()),
    'card_exercise_id': ?cardExerciseId,
    'rest_end': ?_date(restEnd),
    'rest_started_at': ?_date(restStartedAt),
    'paused_at': ?_date(pausedAt),
    'paused_seconds': pausedSeconds,
    'custom_rest_seconds': customRestSeconds,
    'progression_baseline': {
      for (final MapEntry(:key, :value) in progressionBaseline.entries)
        key: {'weight_kg': ?value.weightKg, 'reps': ?value.reps},
    },
    'acknowledged_note_template_ids': acknowledgedNoteTemplateIds.toList(),
    'last_seen_set_completion': ?_date(lastSeenSetCompletion),
    'saved': ?saved?.name,
  };

  static r.SuggestedSet _baseline(Map<String, Object?> set) => r.SuggestedSet(
    weightKg: (set['weight_kg'] as num?)?.toDouble(),
    reps: set['reps'] as int?,
  );

  static Map<String, Object?>? _date(DateTime? date) =>
      date == null ? null : {m.timestampTag: m.formatContractTimestamp(date)};
}

/// Where the active session is kept between launches.
abstract interface class ActiveSessionStore {
  /// The session kept, or `null` when none is.
  Future<ActiveSessionState?> load();

  /// Keeps [state] in place of whatever was kept.
  Future<void> save(ActiveSessionState state);

  /// Forgets the active session: finished and saved, or discarded.
  Future<void> clear();
}

/// Keeps the active session in memory only, for the staging flavor and
/// tests. It does not survive the app being killed.
class InMemoryActiveSessionStore implements ActiveSessionStore {
  /// The state saved last, as JSON, so a load is a copy as a file's is.
  Map<String, Object?>? _json;

  @override
  Future<ActiveSessionState?> load() async =>
      _json == null ? null : ActiveSessionState.fromJson(_json!);

  @override
  Future<void> save(ActiveSessionState state) async =>
      _json = jsonDecode(jsonEncode(state.toJson())) as Map<String, Object?>;

  @override
  Future<void> clear() async => _json = null;
}

/// Keeps the active session in a JSON file, written whole to a temporary
/// file and renamed over the last, so a kill mid-write leaves the previous
/// state rather than half of one.
class FileActiveSessionStore implements ActiveSessionStore {
  /// Keeps it at `file`; the app passes one in its support directory.
  new(this._file);

  final File _file;

  File get _temporary => File('${_file.path}.tmp');

  /// Where a file this build cannot read is moved, rather than deleted: a
  /// workout is never thrown away unread.
  File get unreadable => File('${_file.path}.unreadable');

  @override
  Future<ActiveSessionState?> load() async {
    if (!_file.existsSync()) return null;
    try {
      return switch (jsonDecode(await _file.readAsString())) {
        final Map<String, Object?> json => ActiveSessionState.fromJson(json),
        final other => throw FormatException('Not an object', other),
      };
    } on FormatException {
      await _file.rename(unreadable.path);
      return null;
    }
  }

  @override
  Future<void> save(ActiveSessionState state) async {
    await _file.parent.create(recursive: true);
    await _temporary.writeAsString(jsonEncode(state.toJson()), flush: true);
    await _temporary.rename(_file.path);
  }

  @override
  Future<void> clear() async {
    if (_file.existsSync()) await _file.delete();
  }
}
