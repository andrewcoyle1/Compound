// Sessions, exercises and sets for the Strava suites (Swift
// `StravaFixture`), and a StravaApi that captures what it was sent (Swift
// `CapturingStravaService`).
import 'package:compound_models/compound_models.dart';
import 'package:strava_repository/strava_repository.dart';

final start = DateTime.fromMillisecondsSinceEpoch(
  1700000000 * 1000,
  isUtc: true,
);

WorkoutSetModel row(
  String id, {
  int? reps = 8,
  double? weightKg = 100,
  int? durationSec,
  double? distanceMeters,
  SetSide? side,
  bool isWarmup = false,
  bool completed = true,
  String? parentSetId,
  double? machineBaseKg,
  ExerciseWeightUnit? weightUnit,
}) => WorkoutSetModel(
  id: id,
  authorId: 'author-1',
  index: 0,
  reps: reps,
  weightKg: weightKg,
  durationSec: durationSec,
  distanceMeters: distanceMeters,
  sideRawValue: side?.value,
  isWarmup: isWarmup,
  completedAt: completed ? start : null,
  dateCreated: start,
  parentSetId: parentSetId,
  machineBaseKg: machineBaseKg,
  weightUnitRawValue: weightUnit?.value,
);

WorkoutExerciseModel exercise({
  required List<WorkoutSetModel> sets,
  String templateId = 'system-barbell-bench-press',
  String? name,
}) => WorkoutExerciseModel(
  id: 'exercise-$templateId',
  authorId: 'author-1',
  templateId: templateId,
  name: name ?? templateId,
  trackingMode: TrackingMode.weightReps,
  index: 0,
  sets: sets,
);

/// `endedAt` is ten minutes after the start unless [running].
WorkoutSessionModel session({
  String id = 'session-1',
  String name = 'Push Day',
  DateTime? dateCreated,
  DateTime? endedAt,
  bool running = false,
  String? notes,
  bool isRestDay = false,
  String authorId = 'author-1',
  List<WorkoutExerciseModel>? exercises,
  int? stravaActivityId,
  DateTime? deletedAt,
  double? pausedSeconds,
}) {
  final created = dateCreated ?? start;
  return WorkoutSessionModel(
    id: id,
    authorId: authorId,
    name: name,
    dateCreated: created,
    dateModified: created,
    endedAt: running
        ? null
        : endedAt ?? created.add(const Duration(minutes: 10)),
    notes: notes,
    exercises:
        exercises ??
        [
          exercise(sets: [row('a')]),
        ],
    isRestDay: isRestDay,
    stravaActivityId: stravaActivityId,
    deletedAt: deletedAt,
    pausedSeconds: pausedSeconds,
  );
}

/// A person's own exercise working [muscles].
ExerciseModel customExercise(
  String id,
  Map<Muscles, MuscleTargetType> muscles,
) => ExerciseModel(
  id: id,
  authorId: 'author-1',
  name: 'Cable Thing',
  trackableMetrics: const [],
  muscleGroups: muscles,
  isBodyweight: false,
  rangeOfMotion: 3,
  stability: 3,
  bodyWeightContribution: 0,
  alternateNames: const [],
  isSystemExercise: false,
  dateCreated: start,
  dateModified: start,
);

/// Captures what was sent. [rejectedTokens] answers a request with those
/// access tokens as Strava answers a revoked one. [statuses] are answered
/// in turn, the first by the upload itself, the last repeated;
/// [uploadErrors] are thrown by uploads in turn before any status is
/// answered.
class CapturingStravaApi implements StravaApi {
  StravaAthlete? athlete = const StravaAthlete(
    id: 7,
    firstname: 'Alex',
    lastname: 'Runner',
  );
  List<String> tokens = ['token-1', 'token-2', 'token-3'];
  int tokenLifetime = 3600;
  int nowSeconds = start.millisecondsSinceEpoch ~/ 1000;
  Set<String> rejectedTokens = {};
  List<StravaUploadStatus> statuses = [
    const StravaUploadStatus(id: 7, activityId: 42),
  ];
  List<Exception> uploadErrors = [];
  Exception? disconnectError;
  Exception? connectError;
  Exception? connectionError;
  final uploaded = <StravaUpload>[];
  final polledIds = <int>[];
  final updates = <({int id, String name, String? description})>[];
  final issuedTokens = <String>[];
  final connects = <({String clientId, String? code, String? refreshToken})>[];
  int disconnectCount = 0;

  @override
  Future<StravaConnectResult> connect({
    required String clientId,
    String? code,
    String? refreshToken,
  }) async {
    connects.add((clientId: clientId, code: code, refreshToken: refreshToken));
    if (connectError case final error?) throw error;
    const connected = StravaAthlete(
      id: 7,
      firstname: 'Alex',
      lastname: 'Runner',
    );
    athlete = connected;
    return StravaConnectResult(
      token: StravaAccessToken(
        accessToken: 'connect-token',
        expiresAt: nowSeconds + tokenLifetime,
      ),
      athlete: connected,
    );
  }

  @override
  Future<StravaAthlete?> connection() async {
    if (connectionError case final error?) throw error;
    return athlete;
  }

  @override
  Future<StravaAccessToken> accessToken() async {
    if (athlete == null) {
      throw const StravaException(StravaFailure.notConnected);
    }
    final token = tokens.isEmpty ? 'token-last' : tokens.removeAt(0);
    issuedTokens.add(token);
    return StravaAccessToken(
      accessToken: token,
      expiresAt: nowSeconds + tokenLifetime,
    );
  }

  @override
  Future<void> disconnect() async {
    if (disconnectError case final error?) throw error;
    disconnectCount++;
    athlete = null;
  }

  @override
  Future<StravaUploadStatus> upload(
    StravaUpload upload,
    String accessToken,
  ) async {
    if (rejectedTokens.contains(accessToken)) {
      throw const StravaException(StravaFailure.authorizationRevoked);
    }
    if (uploadErrors.isNotEmpty) throw uploadErrors.removeAt(0);
    uploaded.add(upload);
    return _nextStatus();
  }

  @override
  Future<StravaUploadStatus> uploadStatus(int id, String accessToken) async {
    polledIds.add(id);
    return _nextStatus();
  }

  @override
  Future<void> updateActivity(
    int id, {
    required String name,
    required String? description,
    required String accessToken,
  }) async {
    if (rejectedTokens.contains(accessToken)) {
      throw const StravaException(StravaFailure.authorizationRevoked);
    }
    updates.add((id: id, name: name, description: description));
  }

  StravaUploadStatus _nextStatus() =>
      statuses.length > 1 ? statuses.removeAt(0) : statuses.first;
}
