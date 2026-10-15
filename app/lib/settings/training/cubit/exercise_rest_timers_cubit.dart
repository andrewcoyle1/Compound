import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/settings/training/logic/workout_settings_rules.dart';
import 'package:equatable/equatable.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// Timer Duration's Exercise Timers: the exercises with a rest of their own
/// and the ones that could have one.
final class const ExerciseRestTimersState({
  final List<ExerciseRestOverride> overrides = const [],
  final List<ExerciseModel> withoutOverride = const [],
  final bool saveFailed = false,
}) extends Equatable {
  @override
  List<Object?> get props => [
    overrides,
    [for (final exercise in withoutOverride) exercise.id],
    saveFailed,
  ];
}

/// The per-exercise rests on Timer Duration (Swift
/// `TimerDurationPresenter`'s exercise overrides), over the user's
/// exercises and the bundled ones. Saves log `TimerDurationView_Save_*`.
class ExerciseRestTimersCubit extends Cubit<ExerciseRestTimersState> {
  new({
    required this._repository,
    required this._analytics,
    required this._uid,
    this._systemExercises = const [],
  }) : super(const ExerciseRestTimersState());

  final TrainingLibraryRepository _repository;
  final AnalyticsRepository _analytics;
  final String _uid;
  final List<ExerciseModel> _systemExercises;
  final _subscriptions = <StreamSubscription<Object?>>[];
  var _settings = const <ExerciseSettingsModel>[];
  var _userExercises = const <ExerciseModel>[];

  static const _screen = 'TimerDurationView';

  /// Starts following the exercise settings and the user's exercises.
  void subscribe() {
    if (_subscriptions.isNotEmpty) return;
    _subscriptions
      ..add(
        _repository.watchExerciseSettings(_uid).listen((settings) {
          _settings = settings;
          _refresh();
        }),
      )
      ..add(
        _repository.watchUserExercises(_uid).listen((exercises) {
          _userExercises = exercises;
          _refresh();
        }),
      );
  }

  void _refresh() {
    final library = [..._userExercises, ..._systemExercises];
    final overrides = exerciseRestOverrides(_settings, library);
    emit(
      ExerciseRestTimersState(
        overrides: overrides,
        withoutOverride: exercisesWithoutRestOverride(overrides, library),
      ),
    );
  }

  /// The rest [exerciseId] has of its own, if any.
  int? overrideFor(String exerciseId) => state.overrides
      .where((override) => override.id == exerciseId)
      .firstOrNull
      ?.seconds;

  /// Sets [exerciseId]'s own rest to [seconds]. Zero clears it rather than
  /// storing a rest of no time, as the exercise's own settings screen does.
  Future<void> setOverride(String exerciseId, int seconds) async {
    if (seconds > 0) {
      await _save(
        () => _repository.saveExerciseSettings(
          _uid,
          ExerciseSettingsModel(
            id: exerciseId,
            authorId: _uid,
            restDurationOverride: seconds,
          ),
        ),
      );
      return;
    }
    if (overrideFor(exerciseId) != null) await remove(exerciseId);
  }

  /// Removes [exerciseId]'s own rest, keeping its note.
  Future<void> remove(String exerciseId) =>
      _save(() => _repository.clearExerciseRestOverride(_uid, exerciseId));

  Future<void> _save(Future<void> Function() write) async {
    _analytics.analytic('${_screen}_Save_Start');
    try {
      await write();
      _analytics.analytic('${_screen}_Save_Success');
    } on Object catch (error) {
      _analytics.severe('${_screen}_Save_Fail', error);
      emit(
        ExerciseRestTimersState(
          overrides: state.overrides,
          withoutOverride: state.withoutOverride,
          saveFailed: true,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await super.close();
  }
}
