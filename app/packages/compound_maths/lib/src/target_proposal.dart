/// Whether the calorie target should move (`TargetProposal.swift`).
///
/// Feedforward with a deadband, at most weekly: the target is the estimate
/// plus the goal rate's daily share of the energy in a kilogram, floored by
/// sex, and moves only when that differs from the current target by more than
/// the estimate's uncertainty, by at most 150 kcal. Before lowering a target
/// the user is eating well above, it says so instead (an [AdherenceNote]). The
/// user confirms every move. See `docs/specs/adaptive-expenditure.md` §4.
library;

import 'package:compound_maths/src/day_key.dart';
import 'package:compound_maths/src/energy_density.dart';
import 'package:compound_maths/src/expenditure_engine.dart';
import 'package:compound_maths/src/formula_expenditure.dart';
import 'package:compound_maths/src/nutrition_targets.dart';

/// The controller's design choices, tuned by replay.
abstract final class TargetProposalTuning {
  /// The deadband is the larger of this and the estimate's SD.
  static const minimumMeaningfulDeltaKcal = 50.0;

  /// The most one proposal moves the target.
  static const maximumStepKcal = 150.0;

  /// A proposal waits until the plan is this many days old.
  static const minimumDaysBetweenChanges = 7;

  /// Mean intake more than 10% over the target counts as eating above it.
  static const adherenceMargin = 0.1;
}

/// The plan the controller reads: its days' calories and the day it was made.
typedef PlanTargets = ({List<double> dayCalories, String createdDay});

/// What the controller has to say: a [TargetProposal] or an [AdherenceNote].
sealed class const TargetOutcome();

/// A suggestion that the target should move, for the user to accept or wave
/// away. Its only reason is that expenditure, or the goal, has moved.
final class const TargetProposal({
  required final double expenditureKcal,

  /// Mean of the current plan's days.
  required final double currentTargetKcal,
  required final double proposedTargetKcal,
  required final double? weeklyTrendChangeKg,
  required final double? goalWeeklyChangeKg,
}) extends TargetOutcome;

/// The user is eating well above the target and the scale shows it, so the
/// message is about the logging, not a lower number.
final class const AdherenceNote({
  required final double targetKcal,

  /// Mean of the last week's complete logged days.
  required final double recentIntakeKcal,
  required final double weeklyTrendChangeKg,
  required final double? goalWeeklyChangeKg,
}) extends TargetOutcome;

/// The whole decision (`TargetProposal.evaluate`); `null` to stay quiet.
///
/// [goalWeeklyChangeKg] is the active goal's signed rate, `null` without one.
TargetOutcome? evaluateTarget({
  required ExpenditureEstimate estimate,
  required PlanTargets? plan,
  double? goalWeeklyChangeKg,
  ExpenditureCalculationMode calculationMode =
      ExpenditureCalculationMode.dynamic,
  double kcalPerKg = EnergyDensity.conventionalKcalPerKg,
  Gender? gender,
}) {
  if (plan == null ||
      plan.dayCalories.isEmpty ||
      estimate.isProvisional ||
      estimate.source != ExpenditureSource.adaptive ||
      calculationMode == ExpenditureCalculationMode.fixed) {
    return null;
  }
  final current =
      plan.dayCalories.reduce((a, b) => a + b) / plan.dayCalories.length;
  final raw =
      estimate.kcal +
      dailyKcalForWeeklyChange(goalWeeklyChangeKg ?? 0, kcalPerKg: kcalPerKg);
  final floor = calorieFloor(gender);
  final delta = (raw > floor ? raw : floor) - current;

  final sd = estimate.sdKcal ?? 0;
  final deadband = sd > TargetProposalTuning.minimumMeaningfulDeltaKcal
      ? sd
      : TargetProposalTuning.minimumMeaningfulDeltaKcal;
  if (!(delta.abs() > deadband)) return null;

  final intake = estimate.recentIntakeKcal;
  final rate = estimate.weeklyTrendChangeKg;
  if (delta < 0 &&
      intake != null &&
      intake > current * (1 + TargetProposalTuning.adherenceMargin) &&
      rate != null &&
      rate > (goalWeeklyChangeKg ?? 0)) {
    return AdherenceNote(
      targetKcal: current,
      recentIntakeKcal: intake,
      weeklyTrendChangeKg: rate,
      goalWeeklyChangeKg: goalWeeklyChangeKg,
    );
  }

  if (daysBetween(plan.createdDay, estimate.day) <
      TargetProposalTuning.minimumDaysBetweenChanges) {
    return null;
  }

  const limit = TargetProposalTuning.maximumStepKcal;
  final step = delta.isFinite ? delta.clamp(-limit, limit) : 0;
  return TargetProposal(
    expenditureKcal: estimate.kcal,
    currentTargetKcal: current,
    proposedTargetKcal: (current + step).roundToDouble(),
    weeklyTrendChangeKg: estimate.weeklyTrendChangeKg,
    goalWeeklyChangeKg: goalWeeklyChangeKg,
  );
}

/// The proposal to show, if any (`TargetProposal.make`): [evaluateTarget]'s,
/// unless it is within 50 kcal of the figure last dismissed.
TargetProposal? proposeTarget({
  required ExpenditureEstimate estimate,
  required PlanTargets? plan,
  double? goalWeeklyChangeKg,
  ExpenditureCalculationMode calculationMode =
      ExpenditureCalculationMode.dynamic,
  double kcalPerKg = EnergyDensity.conventionalKcalPerKg,
  Gender? gender,
  double? dismissedKcal,
}) {
  final outcome = evaluateTarget(
    estimate: estimate,
    plan: plan,
    goalWeeklyChangeKg: goalWeeklyChangeKg,
    calculationMode: calculationMode,
    kcalPerKg: kcalPerKg,
    gender: gender,
  );
  if (outcome is! TargetProposal) return null;
  if (dismissedKcal != null &&
      (outcome.proposedTargetKcal - dismissedKcal).abs() <
          TargetProposalTuning.minimumMeaningfulDeltaKcal) {
    return null;
  }
  return outcome;
}

/// Where a dismissed figure is remembered, per account
/// (`TargetProposal.dismissedDefaultsKey`).
String dismissedProposalKey(String? userId) => userId == null || userId.isEmpty
    ? 'dismissedTargetProposalKcal'
    : 'dismissedTargetProposalKcal.$userId';
