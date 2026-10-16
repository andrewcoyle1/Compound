import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart';

/// One exercise's settings as stored: its units on the device, and its
/// note and rest in `exercise_settings`.
final class const ExerciseSettingsState({
  required final ExerciseModel exercise,
  required final UnitPreference units,
  final String note = '',
  final int? restOverride,
  final WorkoutSettings? settings,
}) extends Equatable {
  /// The rest the app runs without an override.
  int get defaultRest => settings?.defaultRestDurationSeconds ?? 90;

  /// Worked one limb at a time, so the left/right rest means something
  /// here (read off the metrics, as Swift's `isPerSide`).
  bool get isPerSide => exercise.isPerSide;

  /// The rest between the two halves of a set, as a whole percentage of
  /// the rest timer; null when it is off.
  int? get sideSetRestPercent => (settings?.restBetweenSideSets ?? false)
      ? (settings!.sideSetRestScaling * 100).round()
      : null;

  /// The note's first line, or null with none.
  String? get noteSummary {
    final trimmed = note.trim();
    return trimmed.isEmpty ? null : trimmed.split('\n').first;
  }

  ExerciseSettingsState _copy({
    UnitPreference? units,
    String? note,
    int? Function()? restOverride,
    WorkoutSettings? settings,
  }) => ExerciseSettingsState(
    exercise: exercise,
    units: units ?? this.units,
    note: note ?? this.note,
    restOverride: restOverride == null ? this.restOverride : restOverride(),
    settings: settings ?? this.settings,
  );

  @override
  List<Object?> get props => [exercise, units, note, restOverride, settings];
}

/// Exercise Settings (Swift `ExerciseSettingsPresenter`): the exercise's
/// weight and distance units, its own rest, the left/right rest it follows
/// and its note. Units change at once on the device; the rest and the note
/// are written to `exercise_settings`.
class ExerciseSettingsCubit extends Cubit<ExerciseSettingsState> {
  new({
    required ExerciseModel exercise,
    required this._uid,
    required this._library,
    required this._units,
    required this._analytics,
    this._user,
  }) : super(
         ExerciseSettingsState(
           exercise: exercise,
           units: _units.of(_uid, exercise.id, user: _user),
         ),
       ) {
    _subscriptions
      ..add(
        _library.watchExerciseSettings(_uid).listen((all) {
          final mine = all.where((s) => s.id == exercise.id).firstOrNull;
          emit(
            state._copy(
              note: mine?.note ?? '',
              restOverride: () => mine?.restDurationOverride,
            ),
          );
        }, onError: (Object _, StackTrace _) {}),
      )
      ..add(
        _library
            .watchWorkoutSettings(_uid)
            .listen(
              (settings) => emit(state._copy(settings: settings)),
              onError: (Object _, StackTrace _) {},
            ),
      );
  }

  static const _screen = 'ExerciseSettingsView';

  final String _uid;
  final TrainingLibraryRepository _library;
  final UnitPreferenceStore _units;
  final AnalyticsRepository _analytics;
  final UserModel? _user;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  String get _id => state.exercise.id;

  void appeared() => _analytics.appear(_screen);

  void disappeared() => _analytics.disappear(_screen);

  /// The exercise's weight unit from now on (`onSelectWeightUnit`).
  void weightUnitChanged(ExerciseWeightUnit unit) {
    _units.setWeightUnit(_uid, _id, unit, user: _user);
    emit(state._copy(units: _units.of(_uid, _id, user: _user)));
  }

  /// The exercise's distance unit from now on (`onSelectDistanceUnit`).
  void distanceUnitChanged(DistanceUnit unit) {
    _units.setDistanceUnit(_uid, _id, unit, user: _user);
    emit(state._copy(units: _units.of(_uid, _id, user: _user)));
  }

  /// The rest picker's Save: [seconds] as the exercise's own rest, or none
  /// with both wheels at zero. A cleared rest is deleted, not merged away,
  /// so it cannot survive as Swift's merge leaves it.
  Future<void> restChanged(int seconds) async {
    final previous = state.restOverride;
    emit(state._copy(restOverride: () => seconds > 0 ? seconds : null));
    try {
      if (seconds > 0) {
        await _library.saveExerciseSettings(
          _uid,
          ExerciseSettingsModel(
            id: _id,
            authorId: _uid,
            restDurationOverride: seconds,
          ),
        );
      } else if (previous != null) {
        await _library.clearExerciseRestOverride(_uid, _id);
      }
    } on Object catch (error) {
      _warn('${_screen}_SaveRestOverride_Fail', error);
    }
  }

  /// The note sheet's Save. A blank note is written as "", not left out:
  /// a merge would keep the old note. Both apps read "" as none.
  Future<void> noteChanged(String note) async {
    final trimmed = note.trim();
    if (trimmed == state.note.trim()) return;
    emit(state._copy(note: trimmed));
    try {
      await _library.saveExerciseSettings(
        _uid,
        ExerciseSettingsModel(id: _id, authorId: _uid, note: trimmed),
      );
    } on Object catch (error) {
      _warn('${_screen}_SaveNote_Fail', error);
    }
  }

  void _warn(String name, Object error) => _analytics.trackEvent(
    AnalyticsEvent(
      name,
      parameters: {'error_description': '$error'},
      type: LogType.warning,
    ),
  );

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    await super.close();
  }
}
