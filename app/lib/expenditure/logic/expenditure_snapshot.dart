import 'dart:async';

import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/onboarding/logic/diet_plan_builder.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:user_repository/user_repository.dart';

/// Everything `CoreInteractor+Expenditure.swift` reads, as the repositories
/// last gave it: the engine's logs and settings, the check-in's record and
/// break, and the plan and goal a target proposal is measured against.
final class const ExpenditureSnapshot({
  required final NutritionStrategySettings settings,
  final UserModel? user,
  final List<MealLogModel> meals = const [],
  final List<BodyMeasurementEntry> measurements = const [],
  final List<StepsModel> steps = const [],
  final List<NutritionDayAnnotation> annotations = const [],
  final LoggingBreak? loggingBreak,
  final CheckInRecord? checkInRecord,
  final DietPlan? dietPlan,
  final WeightGoal? goal,
}) {
  /// The engine's inputs at [now].
  ExpenditureInputs inputs(DateTime now) => ExpenditureInputs(
    now: now,
    settings: settings,
    user: user,
    meals: meals,
    measurements: measurements,
    steps: steps,
    annotations: annotations,
    loggingBreak: loggingBreak,
    checkInRecord: checkInRecord,
  );
}

/// What the engine says at a moment (`CoreInteractor+Expenditure.swift`):
/// the history, today's estimate, the check-in's state and the proposal or
/// adherence note, each worked out once.
final class ExpenditureFigures {
  /// Works the figures out from [snapshot] at [now]. [dismissedKcal] is the
  /// proposal last waved away, which keeps the same one from coming back.
  factory of(
    ExpenditureSnapshot snapshot,
    DateTime now, {
    double? dismissedKcal,
  }) {
    final inputs = snapshot.inputs(now);
    final history = inputs.history;
    final current = history.last;
    final plan = snapshot.dietPlan;
    final goal = snapshot.goal?.status == GoalStatus.active
        ? snapshot.goal
        : null;
    final user = snapshot.user;
    final openBreak = inputs.openLoggingBreak;
    final kcalPerKg = inputs.kcalPerKg;
    // A break is a break: no proposals to someone who has stopped logging.
    final outcome = openBreak != null
        ? null
        : maths.evaluateTarget(
            estimate: current,
            plan: plan == null
                ? null
                : (
                    dayCalories: [for (final day in plan.days) day.calories],
                    createdDay: localDayKey(plan.createdAt),
                  ),
            goalWeeklyChangeKg: goal == null
                ? null
                : maths.signedWeeklyChangeKg(
                    startingWeightKg: goal.startingWeightKg,
                    targetWeightKg: goal.targetWeightKg,
                    weeklyChangeKg: goal.weeklyChangeKg,
                  ),
            calculationMode:
                snapshot.settings.calculationMode ==
                    ExpenditureCalculationMode.fixed
                ? maths.ExpenditureCalculationMode.fixed
                : maths.ExpenditureCalculationMode.dynamic,
            kcalPerKg: kcalPerKg,
            gender: maths.Gender.tryParse(user?.submittedGender?.value),
          );
    final proposal =
        outcome is maths.TargetProposal &&
            (dismissedKcal == null ||
                (outcome.proposedTargetKcal - dismissedKcal).abs() >=
                    maths.TargetProposalTuning.minimumMeaningfulDeltaKcal)
        ? outcome
        : null;
    return ExpenditureFigures._(
      history: history,
      formulaKcal: inputs.priorKcal,
      current: current,
      proposal: proposal,
      adherenceNote: outcome is maths.AdherenceNote ? outcome : null,
      checkInState: inputs.checkInState,
      checkInWeekStart: inputs.checkInWeekStart,
      openLoggingBreak: openBreak,
    );
  }

  new _({
    required this.history,
    required this.formulaKcal,
    required this.current,
    required this.proposal,
    required this.adherenceNote,
    required this.checkInState,
    required this.checkInWeekStart,
    required this.openLoggingBreak,
  });

  /// One estimate per day through today (frozen at an open break's start).
  final List<maths.ExpenditureEstimate> history;

  /// The profile's formula expenditure, the engine's prior.
  final double formulaKcal;

  /// Today's estimate (`currentExpenditure`).
  final maths.ExpenditureEstimate current;

  /// The pending suggestion that the target should move, or null.
  final maths.TargetProposal? proposal;

  /// Set instead of a proposal when the user is eating well above the
  /// target the engine would lower.
  final maths.AdherenceNote? adherenceNote;

  /// Whether the weekly check-in is waiting.
  final CheckInState checkInState;

  /// The Monday of this week, which a due check-in is for.
  final DateTime checkInWeekStart;

  /// The logging break open now, or null.
  final LoggingBreak? openLoggingBreak;

  /// The week a due check-in is for, or null when none is waiting.
  DateTime? get dueCheckInWeekStart =>
      checkInState == CheckInState.due ? checkInWeekStart : null;
}

/// [plan] rebuilt at [proposal]'s target
/// (`CoreInteractor.acceptTargetProposal`): its own diet choices, the
/// proposal's expenditure and target, the active [mesocycle]'s training
/// days and, as in Swift, no goal.
DietPlan acceptedPlan({
  required DietPlan plan,
  required UserModel user,
  required maths.TargetProposal proposal,
  required DateTime now,
  Mesocycle? mesocycle,
}) => buildDietPlan(
  user: user,
  choices: (
    diet:
        maths.PreferredDiet.tryParse(plan.preferredDiet) ??
        maths.PreferredDiet.balanced,
    distribution:
        maths.CalorieDistribution.tryParse(plan.calorieDistribution) ??
        maths.CalorieDistribution.even,
    protein:
        maths.ProteinIntake.tryParse(plan.proteinIntake) ??
        maths.ProteinIntake.moderate,
  ),
  now: now,
  mesocycle: mesocycle,
  expenditureKcal: proposal.expenditureKcal,
  targetKcal: proposal.proposedTargetKcal,
);

/// A proposal as every accept and dismiss event reports it.
Map<String, Object?> proposalParameters(maths.TargetProposal proposal) => {
  'proposal_current_kcal': proposal.currentTargetKcal,
  'proposal_proposed_kcal': proposal.proposedTargetKcal,
  'proposal_expenditure_kcal': proposal.expenditureKcal,
  'proposal_reason': 'expenditureMoved',
};

/// Follows everything [ExpenditureSnapshot] holds for [uid], emitting once
/// each has arrived and again on every change. The meals and weigh-ins are
/// required: an error reading either is passed on. Without the rest, the
/// defaults: Swift's settings, no break, record, plan or goal.
Stream<ExpenditureSnapshot> watchExpenditure({
  required String uid,
  required UserRepository users,
  required NutritionRepository nutrition,
  required BodyRepository body,
  required CheckInRepository checkIns,
}) => Stream.multi((controller) {
  final pending = <String>{
    'user',
    'meals',
    'measurements',
    'steps',
    'annotations',
    'break',
    'record',
    'settings',
    'plan',
    'goal',
  };
  var snapshot = ExpenditureSnapshot(
    settings: NutritionStrategySettings(authorId: uid),
  );
  final subscriptions = <StreamSubscription<Object?>>[];
  StreamSubscription<WeightGoal?>? goalSubscription;
  String? goalId;
  var watchingGoal = false;

  void update(String part, ExpenditureSnapshot next) {
    snapshot = next;
    pending.remove(part);
    if (pending.isEmpty) controller.add(snapshot);
  }

  ExpenditureSnapshot copy({
    UserModel? Function()? user,
    List<MealLogModel>? meals,
    List<BodyMeasurementEntry>? measurements,
    List<StepsModel>? steps,
    List<NutritionDayAnnotation>? annotations,
    LoggingBreak? Function()? loggingBreak,
    CheckInRecord? Function()? checkInRecord,
    NutritionStrategySettings? settings,
    DietPlan? Function()? dietPlan,
    WeightGoal? Function()? goal,
  }) => ExpenditureSnapshot(
    settings: settings ?? snapshot.settings,
    user: user == null ? snapshot.user : user(),
    meals: meals ?? snapshot.meals,
    measurements: measurements ?? snapshot.measurements,
    steps: steps ?? snapshot.steps,
    annotations: annotations ?? snapshot.annotations,
    loggingBreak: loggingBreak == null ? snapshot.loggingBreak : loggingBreak(),
    checkInRecord: checkInRecord == null
        ? snapshot.checkInRecord
        : checkInRecord(),
    dietPlan: dietPlan == null ? snapshot.dietPlan : dietPlan(),
    goal: goal == null ? snapshot.goal : goal(),
  );

  void listen<T>(
    Stream<T> stream,
    String part,
    ExpenditureSnapshot Function(T value) onData, {
    ExpenditureSnapshot Function()? orElse,
  }) => subscriptions.add(
    stream.listen(
      (value) => update(part, onData(value)),
      onError: (Object error, StackTrace stackTrace) => orElse == null
          ? controller.addError(error, stackTrace)
          : update(part, orElse()),
    ),
  );

  // The goal named by the profile (the uid's without one), as GoalManager.
  void watchGoal(String? id) {
    if (watchingGoal && id == goalId) return;
    watchingGoal = true;
    goalId = id;
    unawaited(goalSubscription?.cancel());
    goalSubscription = body
        .watchCurrentGoal(uid, currentGoalId: id)
        .listen(
          (goal) => update('goal', copy(goal: () => goal)),
          onError: (Object _) => update('goal', copy(goal: () => null)),
        );
  }

  listen(
    users.watchUser(uid),
    'user',
    (user) {
      watchGoal(user?.submittedCurrentGoalId);
      return copy(user: () => user);
    },
    orElse: () {
      watchGoal(null);
      return copy(user: () => null);
    },
  );
  listen(nutrition.watchMeals(uid), 'meals', (meals) => copy(meals: meals));
  listen(
    body.watchMeasurements(uid),
    'measurements',
    (measurements) => copy(measurements: measurements),
  );
  listen(
    body.watchSteps(uid),
    'steps',
    (steps) => copy(steps: steps),
    orElse: copy,
  );
  listen(
    checkIns.watchDayAnnotations(uid),
    'annotations',
    (annotations) => copy(annotations: annotations),
    orElse: copy,
  );
  listen(
    checkIns.watchLoggingBreak(uid),
    'break',
    (loggingBreak) => copy(loggingBreak: () => loggingBreak),
    orElse: copy,
  );
  listen(
    checkIns.watchCheckInRecord(uid),
    'record',
    (record) => copy(checkInRecord: () => record),
    orElse: copy,
  );
  listen(
    checkIns.watchStrategySettings(uid),
    'settings',
    (settings) => copy(settings: settings),
    orElse: copy,
  );
  listen(
    nutrition.watchDietPlan(uid),
    'plan',
    (plan) => copy(dietPlan: () => plan),
    orElse: () => copy(dietPlan: () => null),
  );
  controller.onCancel = () {
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(goalSubscription?.cancel());
  };
});
