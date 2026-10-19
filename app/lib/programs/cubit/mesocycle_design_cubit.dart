import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:program_repository/program_repository.dart';

/// What the editor is doing: editing, writing, or finished with a write
/// that [MesocycleDesignState.lastAction] names.
enum MesocycleDesignStatus { editing, saving, succeeded, failed }

/// The writes the editor makes.
enum MesocycleDesignAction { save, activate, delete }

/// The mesocycle being laid out, as it opened and as it stands, and the
/// day selected.
final class const MesocycleDesignState({
  required final Mesocycle mesocycle,
  required final Mesocycle initial,
  required final String selectedDayId,
  final MesocycleDesignStatus status = MesocycleDesignStatus.editing,
  final MesocycleDesignAction? lastAction,
}) extends Equatable {
  /// The days, in order.
  List<WorkoutTemplateModel> get days => mesocycle.workoutTemplates;

  /// The day selected; the first when the selection has gone.
  WorkoutTemplateModel get selectedDay =>
      days.where((day) => day.workoutId == selectedDayId).firstOrNull ??
      days.first;

  /// Whether anything the editor changes differs from how it opened.
  bool get hasUnsavedChanges => hasUnsavedMesocycleChanges(initial, mesocycle);

  /// Whether Save and Activate are allowed: a workout day, and no write
  /// under way.
  bool get canSave =>
      status != MesocycleDesignStatus.saving && hasWorkoutDay(mesocycle);

  /// Whether the selected day can go: never the last.
  bool get canRemoveDay => days.length > 1;

  MesocycleDesignState copyWith({
    Mesocycle? mesocycle,
    String? selectedDayId,
    MesocycleDesignStatus? status,
    MesocycleDesignAction? lastAction,
  }) => MesocycleDesignState(
    mesocycle: mesocycle ?? this.mesocycle,
    initial: initial,
    selectedDayId: selectedDayId ?? this.selectedDayId,
    status: status ?? this.status,
    lastAction: lastAction ?? this.lastAction,
  );

  @override
  List<Object?> get props => [
    mesocycle.toFirestore(),
    initial.toFirestore(),
    selectedDayId,
    status,
    lastAction,
  ];
}

/// Lays out a mesocycle's days and settings, new or saved (Swift
/// `MesocycleDesignPresenter`, and `MesocycleSettingsPresenter`'s
/// Activate): adds, removes, renames and orders days, keeps their
/// generated names in step, and saves, activates or deletes it. The
/// settings page edits this same state, so the two never disagree.
class MesocycleDesignCubit extends Cubit<MesocycleDesignState> {
  /// Opens [mesocycle] for the user `uid`. `labels` name the days in the user's
  /// language.
  new({
    required Mesocycle mesocycle,
    required this._uid,
    required this._labels,
    required this._programs,
    required this._service,
    required this._analytics,
    this._now = DateTime.now,
    this._newId = newDocumentId,
  }) : super(
         MesocycleDesignState(
           mesocycle: mesocycle,
           initial: mesocycle,
           selectedDayId: mesocycle.workoutTemplates.first.workoutId,
         ),
       ) {
    _analytics.appear(_screen);
  }

  static const _screen = 'ProgramDesignView';

  final String _uid;
  final DayNameLabels _labels;
  final ProgramRepository _programs;
  final ProgramService _service;
  final AnalyticsRepository _analytics;
  final DateTime Function() _now;
  final String Function() _newId;

  /// Records another screen of the editor appearing (Mesocycle Settings).
  void appeared(String screen) => _analytics.appear(screen);

  /// Records another screen of the editor going.
  void disappeared(String screen) => _analytics.disappear(screen);

  /// Shows [dayId].
  void selectDay(String dayId) => emit(state.copyWith(selectedDayId: dayId));

  /// Appends a rest day and selects it.
  void addDay() {
    final id = _newId();
    emit(
      state.copyWith(
        mesocycle: addingDay(
          state.mesocycle,
          id: id,
          now: _now(),
          labels: _labels,
        ),
        selectedDayId: id,
      ),
    );
  }

  /// Removes the selected day, unless it is the last, and selects the
  /// first.
  void removeSelectedDay() {
    if (!state.canRemoveDay) return;
    final mesocycle = removingDay(
      state.mesocycle,
      state.selectedDay.workoutId,
      labels: _labels,
    );
    emit(
      state.copyWith(
        mesocycle: mesocycle,
        selectedDayId: mesocycle.workoutTemplates.first.workoutId,
      ),
    );
  }

  /// Names the day [dayId] [name], which the generated names then leave.
  void renameDay(String dayId, String name) => emit(
    state.copyWith(mesocycle: renamingDay(state.mesocycle, dayId, name)),
  );

  /// The selected day's exercises as the workout editor left them; a rest
  /// day given exercises takes a workout's name, and the reverse
  /// (`selectedWorkoutTemplateModelExercises`).
  void setSelectedDayExercises(List<WorkoutTemplateExercise> exercises) => emit(
    state.copyWith(
      mesocycle: settingDayExercises(
        state.mesocycle,
        state.selectedDay.workoutId,
        exercises,
        labels: _labels,
      ),
    ),
  );

  /// Changes the settings (Swift's settings `Binding`).
  void edit({
    String? name,
    String? icon,
    String? colour,
    int? numMicrocycles,
    DeloadType? deload,
    bool? periodisation,
    List<WorkoutTemplateModel>? days,
  }) => emit(
    state.copyWith(
      mesocycle: editedMesocycle(
        state.mesocycle,
        name: name,
        icon: icon,
        colour: colour,
        numMicrocycles: numMicrocycles,
        deload: deload,
        periodisation: periodisation,
        workoutTemplates: days,
      ),
    ),
  );

  /// Saves the mesocycle as it stands.
  Future<void> save() => _write(
    MesocycleDesignAction.save,
    'Save',
    () => _programs.saveMesocycle(state.mesocycle),
  );

  /// Saves the mesocycle and makes it the one followed. [screen] names the
  /// screen for the events: this one, or `ProgramSettingsView`.
  Future<void> activate({String screen = _screen}) => _write(
    MesocycleDesignAction.activate,
    'Activate',
    () => _service.activateMesocycle(_uid, state.mesocycle),
    screen: screen,
  );

  /// Deletes the mesocycle.
  Future<void> delete() => _write(
    MesocycleDesignAction.delete,
    'Delete',
    () => _service.deleteMesocycle(_uid, state.mesocycle.id),
    always: true,
  );

  /// Runs [write] between `<screen>_<name>_Start` and `_Success` or a
  /// severe `_Fail`. Save and Activate need a workout day; a second tap
  /// while one write runs does nothing.
  Future<void> _write(
    MesocycleDesignAction action,
    String name,
    Future<void> Function() write, {
    String screen = _screen,
    bool always = false,
  }) async {
    if (state.status == MesocycleDesignStatus.saving) return;
    if (!always && !state.canSave) return;
    emit(state.copyWith(status: MesocycleDesignStatus.saving));
    _analytics.analytic('${screen}_${name}_Start');
    try {
      await write();
      _analytics.analytic('${screen}_${name}_Success');
      emit(
        state.copyWith(
          status: MesocycleDesignStatus.succeeded,
          lastAction: action,
        ),
      );
    } on Object catch (error) {
      _analytics.severe('${screen}_${name}_Fail', error);
      emit(
        state.copyWith(
          status: MesocycleDesignStatus.failed,
          lastAction: action,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _analytics.disappear(_screen);
    return super.close();
  }
}
