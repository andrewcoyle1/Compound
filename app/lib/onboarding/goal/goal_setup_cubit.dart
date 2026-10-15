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
  ];
}

/// Setting the first goal (Swift `OverarchingObjectivePresenter` through
/// `GoalSummaryPresenter`): maintaining skips the target and rate.
///
/// The save follows `GoalSummaryPresenter.saveGoal` and
/// `GoalManager.saveGoal`: the new goal under its own id, then the goal it
/// replaces marked abandoned if it was active (best effort), then
/// `submitted_current_goal_id`. The AppBloc then moves on to the gym.
class GoalSetupCubit extends Cubit<GoalSetupState> {
  new({
    required this._userRepository,
    required this._bodyRepository,
    required this._analyticsRepository,
    required this._profile,
    this._now = DateTime.now,
    this._newId = newDocumentId,
  }) : super(const GoalSetupState()) {
    _analyticsRepository.appear(state.question.screen, onboardingParameters);
  }

  final UserRepository _userRepository;
  final BodyRepository _bodyRepository;
  final AnalyticsRepository _analyticsRepository;
  final UserModel _profile;
  final DateTime Function() _now;
  final String Function() _newId;
  WeightGoal? _replaced;

  String get _uid => _profile.userId;

  /// Reads the latest weigh-in and the goal this one replaces.
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
    emit(
      state.copyWith(
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
      ..disappear(state.question.screen, onboardingParameters)
      ..appear(question.screen, onboardingParameters);
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
  /// otherwise the target wheel opens at today's weight, within its range.
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

  void targetContinued() {
    final rules = state.rateRules;
    if (!state.canContinueTarget || rules == null) return;
    _analyticsRepository.info('Onboarding_TargetWeight_Navigate');
    emit(state.copyWith(rateKg: rules.initial));
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
      final goal = WeightGoal(
        goalId: _newId(),
        userId: _uid,
        objective: objective,
        startingWeightKg: current,
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
      _analyticsRepository
        ..analytic('Onboarding_Goal_Save_Success')
        ..info('Onboarding_Goal_Navigation');
      emit(state.copyWith(status: GoalSetupStatus.saved));
    } on Object catch (error) {
      _analyticsRepository.severe('Onboarding_Goal_Save_Fail', error);
      emit(state.copyWith(status: GoalSetupStatus.failure));
    }
  }

  @override
  Future<void> close() {
    _analyticsRepository.disappear(state.question.screen, onboardingParameters);
    return super.close();
  }
}
