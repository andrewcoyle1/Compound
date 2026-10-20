import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/settings/training/logic/workout_settings_rules.dart';
import 'package:equatable/equatable.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// The workout settings a screen shows, and whether its last save failed.
final class const WorkoutSettingsState({
  /// Null until the first read.
  final WorkoutSettings? settings,
  final bool saveFailed = false,
}) extends Equatable {
  @override
  List<Object?> get props => [settings?.toFirestore(), saveFailed];
}

/// One workout-settings screen (Swift `WorkoutSettingsPresenter`,
/// `RestTimerSettingsPresenter`, `SmartProgressionSettingsPresenter` and
/// `TimerDurationPresenter`): each change writes the whole document back.
///
/// It follows [TrainingLibraryRepository.watchWorkoutSettings] rather than
/// keeping a copy, so a change made on another settings screen is never
/// written over when this one saves (Swift re-reads on appear for this).
/// Events carry the screen's Swift name: `<screen>_Save_Start` and so on.
class WorkoutSettingsCubit extends Cubit<WorkoutSettingsState> {
  new({
    required this._repository,
    required this._analytics,
    required this._uid,
    required this._screen,
  }) : super(const WorkoutSettingsState());

  final TrainingLibraryRepository _repository;
  final AnalyticsRepository _analytics;
  final String _uid;
  final String _screen;
  StreamSubscription<WorkoutSettings>? _subscription;

  /// Starts following the stored settings.
  void subscribe() => _subscription ??= _repository
      .watchWorkoutSettings(_uid)
      .listen((settings) => emit(WorkoutSettingsState(settings: settings)));

  /// `<screen>_Appear`.
  void appeared() => _analytics.appear(_screen);

  /// `<screen>_Disappear`.
  void disappeared() => _analytics.disappear(_screen);

  /// Sets [fields] (keys from `WorkoutSettingsKeys`; null clears an
  /// optional one) and saves the whole document. Nothing is saved when
  /// nothing changes, or before the settings have been read.
  Future<void> change(Map<String, Object?> fields) async {
    final current = state.settings;
    if (current == null) return;
    final next = WorkoutSettingsState(settings: withFields(current, fields));
    if (next == WorkoutSettingsState(settings: current)) return;
    emit(next);
    _analytics.analytic('${_screen}_Save_Start');
    try {
      await _repository.saveWorkoutSettings(next.settings!);
      _analytics.analytic('${_screen}_Save_Success');
    } on Object catch (error) {
      _analytics.severe('${_screen}_Save_Fail', error);
      emit(WorkoutSettingsState(settings: state.settings, saveFailed: true));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
