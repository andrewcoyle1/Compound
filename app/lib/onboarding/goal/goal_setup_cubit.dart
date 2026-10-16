import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/document_id.dart';
import 'package:compound/onboarding/logic/body_units.dart';
import 'package:compound/onboarding/logic/diet_plan_builder.dart';
import 'package:compound/onboarding/logic/goal_rules.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

/// The goal questions (Swift folders `6 - GoalSetting/1–4`).
enum GoalQuestion {
  objective('OverarchingObjectiveView'),
  targetWeight('TargetWeightView'),
  rate('WeightRateView'),
  summary('GoalSummaryView');

  new(this.screen);

  final String screen;
}

enum GoalSetupStatus { loading, ready, saving, saved, failure }

final class const GoalSetupState({
  final GoalQuestion question = GoalQuestion.objective,
  final GoalSetupStatus status = GoalSetupStatus.loading,

  /// The latest weigh-in, else the weight given at onboarding
  /// (`BodyMeasurementsManager.currentWeightKilograms`).
  final double? currentKg,
  final double? heightCm,
  final WeightUnitPreference weightUnit = WeightUnitPreference.kilograms,

  /// The formula expenditure, for the rate screen's calorie estimate.
  final double expenditureKcal = 0,
  final double floorKcal = 1350,
  final OverarchingObjective? objective,

  /// The target, in kilograms, as the wheel last set it.
  final double targetKg = 0,

  /// The target wheel's value, in [weightUnit].
  final int targetWheel = 0,

  /// The weekly rate, in kilograms (unsigned).
  final double rateKg = 0,

  /// Opened after onboarding, from Settings or Progress (Swift
  /// `isStandaloneMode`): no progress bar, Complete instead of Continue, and
  /// the flow closes once the goal is saved.
  final bool isStandalone = false,

  /// The running goal being edited, which keeps where it started; null
  /// when setting a new one.
  final WeightGoal? editing,
}) extends Equatable {
  bool get canContinueObjective => objective != null && currentKg != null;

  bool get canContinueTarget =>
      objective != null &&
      canContinueWithTarget(
        objective!,
        targetKg: targetKg,
        currentKg: currentKg,
      );

  WeightRateRules? get rateRules => objective == null
      ? null
      : WeightRateRules(
          objective: objective!,
          currentKg: currentKg,
          heightCm: heightCm,
        );

  ({int min, int max})? get targetRange => switch (objective) {
    null => null,
    final objective => switch (weightUnit) {
      WeightUnitPreference.kilograms => targetKilogramRange(
        objective,
        currentKg: currentKg,
        heightCm: heightCm,
      ),
      WeightUnitPreference.pounds => targetPoundRange(
        objective,
        currentKg: currentKg,
        heightCm: heightCm,
      ),
    },
  };

  GoalSetupState copyWith({
    GoalQuestion? question,
    GoalSetupStatus? status,
    double? currentKg,
    double? heightCm,
    WeightUnitPreference? weightUnit,
    double? expenditureKcal,
    double? floorKcal,
    OverarchingObjective? objective,
    double? targetKg,
    int? targetWheel,
    double? rateKg,
    WeightGoal? editing,
  }) => GoalSetupState(
    question: question ?? this.question,
    status: status ?? this.status,
    currentKg: currentKg ?? this.currentKg,
    heightCm: heightCm ?? this.heightCm,
    weightUnit: weightUnit ?? this.weightUnit,
    expenditureKcal: expenditureKcal ?? this.expenditureKcal,
    floorKcal: floorKcal ?? this.floorKcal,
    objective: objective ?? this.objective,
    targetKg: targetKg ?? this.targetKg,
    targetWheel: targetWheel ?? this.targetWheel,
    rateKg: rateKg ?? this.rateKg,
    isStandalone: isStandalone,
    editing: editing ?? this.editing,
  );

  @override
  List<Object?> get props => [
    question,
    status,
    currentKg,
    heightCm,
    weightUnit,
    expenditureKcal,
    floorKcal,
    objective,
    targetKg,
    targetWheel,
    rateKg,
    isStandalone,
    editing,
  ];
}

/// Rebuilds the diet plan for a goal just saved
/// (`CoreInteractor.applyGoalToDietPlan`; see `applyGoalToDietPlan`).
typedef GoalPlanApplier = Future<void> Function(WeightGoal goal);

/// Setting a goal (Swift `OverarchingObjectivePresenter` through
/// `GoalSummaryPresenter`): maintaining skips the target and rate. In
/// onboarding, or standalone from Settings and Progress, where it can edit
/// the running goal instead of starting a new one.
///
/// A new goal is saved as `GoalSummaryPresenter.saveGoal` and
/// `GoalManager.saveGoal` do: under its own id, then the goal it replaces
/// marked abandoned if it was active (best effort), then
/// `submitted_current_goal_id`. An edit changes only the objective, target
/// and rate (`GoalManager.updateGoal`). Either way the diet plan then
/// follows the goal ([GoalPlanApplier]); a failure there is logged, since
/// the goal itself saved. In onboarding the AppBloc then moves on to the
/// gym; standalone, the flow closes.
class GoalSetupCubit extends Cubit<GoalSetupState> {
  new({
    required this._userRepository,
    required this._bodyRepository,
    required this._analyticsRepository,
    required this._profile,
    bool isStandalone = false,
    this._editsCurrentGoal = false,
    this._applyToDietPlan,
    this._now = DateTime.now,
    this._newId = newDocumentId,
  }) : super(GoalSetupState(isStandalone: isStandalone)) {
    _analyticsRepository.appear(state.question.screen, _parameters);
  }

  final UserRepository _userRepository;
  final BodyRepository _bodyRepository;
  final AnalyticsRepository _analyticsRepository;
  final UserModel _profile;
  final DateTime Function() _now;
  final String Function() _newId;
  final bool _editsCurrentGoal;
  final GoalPlanApplier? _applyToDietPlan;
  WeightGoal? _replaced;

  String get _uid => _profile.userId;

  /// Whether the screen is part of onboarding, as every appear and
  /// disappear reports it.
  Map<String, Object?> get _parameters => {
    'is_onboarding': !state.isStandalone,
  };

  /// The goal's own figure for [objective], when editing a goal toward the
  /// same objective: the target and rate open on it.
  WeightGoal? _editedToward(OverarchingObjective objective) =>
      state.editing?.objective == objective ? state.editing : null;

  /// Reads the latest weigh-in and the goal this one replaces, which is the
  /// one edited when editing and it is still running.
  Future<void> load() async {
    var weighIns = const <BodyMeasurementEntry>[];
    try {
      weighIns = await _bodyRepository.watchMeasurements(_uid).first;
      _replaced = await _bodyRepository
          .watchCurrentGoal(
            _uid,
            currentGoalId: _profile.submittedCurrentGoalId,
          )
          .first;
    } on Object catch (_) {}
    BodyMeasurementEntry? latest;
    for (final entry in weighIns) {
      if (entry.weightKg == null) continue;
      if (latest == null || entry.date.isAfter(latest.date)) latest = entry;
    }
    final gender = maths.Gender.tryParse(_profile.submittedGender?.value);
    final replaced = _replaced;
    final editing =
        _editsCurrentGoal &&
            replaced != null &&
            replaced.status == GoalStatus.active
        ? replaced
        : null;
    emit(
      state.copyWith(
        editing: editing,
        objective: editing?.objective,
        status: GoalSetupStatus.ready,
        currentKg: latest?.weightKg ?? _profile.submittedWeightKilograms,
        heightCm: _profile.submittedHeightCentimeters,
        weightUnit: _profile.submittedWeightUnitPreference,
        expenditureKcal: formulaExpenditure(_profile, now: _now()),
        floorKcal: maths.calorieFloor(gender),
      ),
    );
  }

  void _go(GoalQuestion question) {
    _analyticsRepository
      ..disappear(state.question.screen, _parameters)
      ..appear(question.screen, _parameters);
    emit(state.copyWith(question: question, status: GoalSetupStatus.ready));
  }

  /// Back one question; maintaining comes back from the summary to the
  /// objective. False on the first.
  bool back() {
    final previous = switch (state.question) {
      GoalQuestion.objective => null,
      GoalQuestion.targetWeight => GoalQuestion.objective,
      GoalQuestion.rate => GoalQuestion.targetWeight,
      GoalQuestion.summary =>
        state.objective == OverarchingObjective.maintain
            ? GoalQuestion.objective
            : GoalQuestion.rate,
    };
    if (previous == null) return false;
    _go(previous);
    return true;
  }

  void objectiveSelected(OverarchingObjective objective) =>
      emit(state.copyWith(objective: objective));

  /// Maintaining goes straight to the summary at today's weight and no rate;
  /// otherwise the target wheel opens at today's weight, or at the edited
  /// goal's target toward the same objective, within its range.
  void objectiveContinued() {
    final objective = state.objective;
    final current = state.currentKg;
    if (objective == null || current == null) return;
    _analyticsRepository.info('OverarchingObjecting_Navigate');
    if (objective == OverarchingObjective.maintain) {
      emit(state.copyWith(targetKg: current, rateKg: 0));
      _go(GoalQuestion.summary);
      return;
    }
    final wheel = initialTargetWheelValue(
      objective,
      unit: state.weightUnit,
      currentKg: current,
      heightCm: state.heightCm,
      openingKg: _editedToward(objective)?.targetWeightKg,
    );
    targetWheelChanged(wheel);
    _go(GoalQuestion.targetWeight);
  }

  /// `updateFromKilograms` / `updateFromPounds`.
  void targetWheelChanged(int value) => emit(
    state.copyWith(
      targetWheel: value,
      targetKg: switch (state.weightUnit) {
        WeightUnitPreference.kilograms => value.toDouble(),
        WeightUnitPreference.pounds => lbsToKg(value.toDouble()),
      },
    ),
  );

  /// On to the rate, opening on the default, or on the edited goal's rate
  /// toward the same objective.
  void targetContinued() {
    final rules = state.rateRules;
    final objective = state.objective;
    if (!state.canContinueTarget || rules == null || objective == null) {
      return;
    }
    _analyticsRepository.info('Onboarding_TargetWeight_Navigate');
    final edited = _editedToward(objective)?.weeklyChangeKg ?? 0;
    emit(state.copyWith(rateKg: edited > 0 ? edited : rules.initial));
    _go(GoalQuestion.rate);
  }

  void rateChanged(double rateKg) {
    final rules = state.rateRules;
    if (rules == null) return;
    emit(state.copyWith(rateKg: rules.snapped(rateKg)));
  }

  void rateContinued() {
    if (!(state.rateKg > 0)) return;
    _analyticsRepository.info('Onboarding_WeightRate_Navigate');
    _go(GoalQuestion.summary);
  }

  /// Saves the goal (see the class comment).
  Future<void> save() async {
    final objective = state.objective;
    if (objective == null ||
        state.status == GoalSetupStatus.saving ||
        state.status == GoalSetupStatus.saved) {
      return;
    }
    _analyticsRepository.analytic('Onboarding_Goal_Save_Start');
    final current = state.currentKg;
    if (current == null) {
      _analyticsRepository.severe(
        'Onboarding_Goal_Save_Fail',
        'Current weight not available.',
      );
      emit(state.copyWith(status: GoalSetupStatus.failure));
      return;
    }
    emit(state.copyWith(status: GoalSetupStatus.saving));
    try {
      final goal = await _write(objective, current);
      await _applyGoal(goal);
      _analyticsRepository.analytic('Onboarding_Goal_Save_Success');
      if (!state.isStandalone) {
        _analyticsRepository.info('Onboarding_Goal_Navigation');
      }
      emit(state.copyWith(status: GoalSetupStatus.saved));
    } on Object catch (error) {
      _analyticsRepository.severe('Onboarding_Goal_Save_Fail', error);
      emit(state.copyWith(status: GoalSetupStatus.failure));
    }
  }

  /// Edits the running goal, or writes a new one and points the profile at
  /// it; the goal as it now stands.
  Future<WeightGoal> _write(
    OverarchingObjective objective,
    double currentKg,
  ) async {
    final editing = state.editing;
    if (editing != null) {
      // Editing keeps where the goal started; only what it aims for changes.
      await _bodyRepository.editGoal(
        _uid,
        editing.goalId,
        objective: objective,
        targetWeightKg: state.targetKg,
        weeklyChangeKg: state.rateKg,
      );
      return WeightGoal(
        goalId: editing.goalId,
        userId: editing.userId,
        objective: objective,
        startingWeightKg: editing.startingWeightKg,
        targetWeightKg: state.targetKg,
        weeklyChangeKg: state.rateKg,
        createdAt: editing.createdAt,
        status: editing.status,
        completedAt: editing.completedAt,
      );
    }
    final goal = WeightGoal(
      goalId: _newId(),
      userId: _uid,
      objective: objective,
      startingWeightKg: currentKg,
      targetWeightKg: state.targetKg,
      weeklyChangeKg: state.rateKg,
      createdAt: _now(),
      status: GoalStatus.active,
    );
    await _bodyRepository.saveGoal(goal);
    final replaced = _replaced;
    if (replaced != null &&
        replaced.goalId != goal.goalId &&
        replaced.status == GoalStatus.active) {
      try {
        await _bodyRepository.abandonGoal(_uid, replaced.goalId);
      } on Object catch (_) {
        // Best effort, as Swift's `try?`: the new goal stands either way.
      }
    }
    await _userRepository.updateUserFields(_uid, [
      UserField.submittedCurrentGoalId(goal.goalId),
    ]);
    return goal;
  }

  /// The goal sets the calorie target from now, not from the next
  /// check-in. A failure leaves the old targets, which the next check-in
  /// corrects; it is logged rather than shown, since the goal did save.
  Future<void> _applyGoal(WeightGoal goal) async {
    try {
      await _applyToDietPlan?.call(goal);
    } on Object catch (error) {
      _analyticsRepository.severe(
        'Onboarding_Goal_ApplyToDietPlan_Fail',
        error,
      );
    }
  }

  @override
  Future<void> close() {
    _analyticsRepository.disappear(state.question.screen, _parameters);
    return super.close();
  }
}
