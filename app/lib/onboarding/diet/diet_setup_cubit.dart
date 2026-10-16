import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/onboarding/logic/diet_plan_builder.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:equatable/equatable.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:user_repository/user_repository.dart';

/// The diet questions (Swift folder `8 - OnboardingDiet`). The calorie
/// floor isn't asked in onboarding (Swift decision 3b): there is only the
/// standard one. From Settings it is shown, to explain the floor, and the
/// intro is not.
enum DietQuestion {
  intro('CustomisingDietProgramView'),
  preferredDiet('PreferredDietView'),
  calorieFloor('CalorieFloorView'),
  distribution('CalorieDistributionView'),
  protein('ProteinIntakeView'),
  plan('DietPlanView');

  new(this.screen);

  final String screen;
}

enum DietSetupStatus { loading, ready, saving, saved, failure }

final class const DietSetupState({
  final DietQuestion question = DietQuestion.intro,
  final DietSetupStatus status = DietSetupStatus.loading,
  final maths.PreferredDiet diet = maths.PreferredDiet.balanced,
  final maths.CalorieDistribution? distribution,
  final maths.ProteinIntake protein = maths.ProteinIntake.moderate,

  /// The active mesocycle's name and training days, for the plan screen.
  final String? mesocycleName,
  final int? trainingDaysPerWeek,

  /// The plan the answers make, on the plan screen.
  final DietPlan? plan,

  /// The formula's resting calories, when a day's target is below them.
  final double? restingKcalAboveTarget,
  final Gender? gender,

  /// The calorie floor picked on its screen; there is only the standard one.
  final String? calorieFloor,

  /// Opened from Settings or the target chart (Swift `isFromSettings`): the
  /// plan is rebuilt and the flow closes, with onboarding left alone.
  final bool isFromSettings = false,
}) extends Equatable {
  DietSetupState copyWith({
    DietQuestion? question,
    DietSetupStatus? status,
    maths.PreferredDiet? diet,
    maths.CalorieDistribution? distribution,
    maths.ProteinIntake? protein,
    String? mesocycleName,
    int? trainingDaysPerWeek,
    DietPlan? plan,
    double? Function()? restingKcalAboveTarget,
    Gender? gender,
    String? calorieFloor,
  }) => DietSetupState(
    question: question ?? this.question,
    status: status ?? this.status,
    diet: diet ?? this.diet,
    distribution: distribution ?? this.distribution,
    protein: protein ?? this.protein,
    mesocycleName: mesocycleName ?? this.mesocycleName,
    trainingDaysPerWeek: trainingDaysPerWeek ?? this.trainingDaysPerWeek,
    plan: plan ?? this.plan,
    restingKcalAboveTarget: restingKcalAboveTarget == null
        ? this.restingKcalAboveTarget
        : restingKcalAboveTarget(),
    gender: gender ?? this.gender,
    calorieFloor: calorieFloor ?? this.calorieFloor,
    isFromSettings: isFromSettings,
  );

  @override
  List<Object?> get props => [
    question,
    status,
    diet,
    distribution,
    protein,
    mesocycleName,
    trainingDaysPerWeek,
    plan,
    restingKcalAboveTarget,
    gender,
    calorieFloor,
    isFromSettings,
  ];
}

/// The diet step (Swift `CustomisingDietProgramPresenter` through
/// `DietPlanPresenter`): use the recommended answers, or answer the diet,
/// distribution and protein questions; then the plan is saved and
/// onboarding marked complete, which the AppBloc follows to the tabs.
///
/// From Settings it starts at the diet, asks the floor too, and only saves
/// the plan.
class DietSetupCubit extends Cubit<DietSetupState> {
  new({
    required this._nutritionRepository,
    required this._programRepository,
    required this._bodyRepository,
    required this._userRepository,
    required this._analyticsRepository,
    required this._profile,
    bool isFromSettings = false,
    this._now = DateTime.now,
  }) : super(
         DietSetupState(
           gender: _profile.submittedGender,
           isFromSettings: isFromSettings,
           question: isFromSettings
               ? DietQuestion.preferredDiet
               : DietQuestion.intro,
         ),
       ) {
    _analyticsRepository.appear(
      state.question.screen,
      _parameters(state.question),
    );
  }

  final NutritionRepository _nutritionRepository;
  final ProgramRepository _programRepository;
  final BodyRepository _bodyRepository;
  final UserRepository _userRepository;
  final AnalyticsRepository _analyticsRepository;
  final UserModel _profile;
  final DateTime Function() _now;

  Mesocycle? _mesocycle;
  WeightGoal? _goal;
  DietPlan? _currentPlan;

  String get _uid => _profile.userId;

  /// The intro logs no parameters; the rest say whether they are part of
  /// onboarding.
  Map<String, Object?>? _parameters(DietQuestion question) =>
      question == DietQuestion.intro
      ? null
      : {'is_onboarding': !state.isFromSettings};

  /// Reads the active mesocycle, the goal and any plan already saved, whose
  /// answers the questions open on, as when Swift rebuilds a plan.
  Future<void> load() async {
    final mesocycleId = _profile.submittedActiveMesocycleId;
    try {
      _mesocycle = (await _programRepository.watchMesocycles(_uid).first)
          .where((mesocycle) => mesocycle.id == mesocycleId)
          .firstOrNull;
    } on Object catch (_) {}
    try {
      _goal = await _bodyRepository
          .watchCurrentGoal(
            _uid,
            currentGoalId: _profile.submittedCurrentGoalId,
          )
          .first;
    } on Object catch (_) {}
    try {
      _currentPlan = await _nutritionRepository.watchDietPlan(_uid).first;
    } on Object catch (_) {}
    final plan = _currentPlan;
    emit(
      state.copyWith(
        status: DietSetupStatus.ready,
        diet: maths.PreferredDiet.tryParse(plan?.preferredDiet),
        protein: maths.ProteinIntake.tryParse(plan?.proteinIntake),
        distribution: maths.CalorieDistribution.tryParse(
          plan?.calorieDistribution,
        ),
      ),
    );
  }

  void _go(DietQuestion question) {
    _analyticsRepository
      ..disappear(state.question.screen, _parameters(state.question))
      ..appear(question.screen, _parameters(question));
    emit(state.copyWith(question: question, status: DietSetupStatus.ready));
  }

  /// Back one question; the plan reached by "Use Recommended Plan" goes back
  /// to the intro, and onboarding's distribution to the diet. False on the
  /// first question.
  bool back() {
    final previous = switch (state.question) {
      DietQuestion.intro => null,
      DietQuestion.preferredDiet =>
        state.isFromSettings ? null : DietQuestion.intro,
      DietQuestion.distribution =>
        state.isFromSettings
            ? DietQuestion.calorieFloor
            : DietQuestion.preferredDiet,
      DietQuestion.plan when _usedRecommended => DietQuestion.intro,
      final question => DietQuestion.values[question.index - 1],
    };
    if (previous == null) return false;
    _go(previous);
    return true;
  }

  bool _usedRecommended = false;

  /// Skips the questions with their recommended answers.
  void useRecommendedPlan() {
    _analyticsRepository.info('Onboarding_CustProgram_UseRecommended');
    _usedRecommended = true;
    final choices = recommendedDietChoices(_mesocycle);
    _showPlan(choices);
  }

  void customize() {
    _analyticsRepository.info('Onboarding_CustProgram_Navigate');
    _usedRecommended = false;
    _go(DietQuestion.preferredDiet);
  }

  void dietSelected(maths.PreferredDiet diet) =>
      emit(state.copyWith(diet: diet));

  /// On to the floor from Settings, which opens on the plan's floor, else
  /// the standard one (`CalorieFloorPresenter.prefillCalorieFloor`); in
  /// onboarding straight to the distribution, at the standard floor.
  void dietContinued() {
    _analyticsRepository.info('Onboarding_PrefDiet_Navigate');
    if (!state.isFromSettings) {
      _toDistribution();
      return;
    }
    final fromPlan = _currentPlan?.calorieFloor == standardCalorieFloor;
    _analyticsRepository.info('Onboarding_CalFloor_Prefilled', {
      'floor': standardCalorieFloor,
      'reason': fromPlan ? 'current_plan' : 'default',
    });
    emit(state.copyWith(calorieFloor: standardCalorieFloor));
    _go(DietQuestion.calorieFloor);
  }

  void calorieFloorSelected(String floor) =>
      emit(state.copyWith(calorieFloor: floor));

  void calorieFloorContinued() {
    if (state.calorieFloor == null) return;
    _analyticsRepository.info('Onboarding_CalFloor_Navigate', const {});
    _toDistribution();
  }

  /// On to the distribution, opening on the plan's own answer, else the
  /// one the mesocycle suggests (`CalorieDistributionPresenter.init`).
  void _toDistribution() {
    _go(DietQuestion.distribution);
    final mesocycle = _mesocycle;
    if (mesocycle == null) return;
    final days = trainingDays(mesocycle);
    if (state.distribution == null) {
      final recommended = recommendedDistribution(mesocycle);
      emit(state.copyWith(distribution: recommended));
      _analyticsRepository.info('Onboarding_CalDist_Prefilled', {
        'distribution': recommended.name,
        'reason': 'training_days_$days',
      });
    }
    _analyticsRepository.info('Onboarding_CalDist_TrainingContextLoaded', {
      'daysPerWeek': days,
    });
  }

  void distributionSelected(maths.CalorieDistribution distribution) =>
      emit(state.copyWith(distribution: distribution));

  void distributionContinued() {
    if (state.distribution == null) return;
    _analyticsRepository.info('Onboarding_CalDist_Navigate');
    _go(DietQuestion.protein);
  }

  void proteinSelected(maths.ProteinIntake protein) =>
      emit(state.copyWith(protein: protein));

  void proteinContinued() {
    final distribution = state.distribution;
    if (distribution == null) return;
    _analyticsRepository.info('Onboarding_ProteinIntake_Navigate');
    _showPlan((
      diet: state.diet,
      distribution: distribution,
      protein: state.protein,
    ));
  }

  /// Builds the plan (`DietPlanPresenter.createPlan`), noting when a day is
  /// below the resting calories.
  void _showPlan(DietChoices choices) {
    final now = _now();
    final plan = buildDietPlan(
      user: _profile,
      choices: choices,
      now: now,
      goal: _goal,
      mesocycle: _mesocycle,
    );
    final resting = formulaRestingKcal(_profile, now: now);
    final lowest = plan.days.isEmpty
        ? 0.0
        : plan.days.map((day) => day.calories).reduce((a, b) => a < b ? a : b);
    final mesocycle = _mesocycle;
    _go(DietQuestion.plan);
    emit(
      state.copyWith(
        plan: plan,
        mesocycleName: mesocycle?.name,
        trainingDaysPerWeek: mesocycle == null ? null : trainingDays(mesocycle),
        restingKcalAboveTarget: () =>
            resting.isFinite && lowest > 0 && lowest < resting ? resting : null,
      ),
    );
  }

  /// Saves the plan, then marks onboarding complete, as
  /// `DietPlanPresenter.navigate` does for onboarding; from Settings, only
  /// the plan.
  Future<void> save() async {
    final plan = state.plan;
    if (plan == null ||
        state.status == DietSetupStatus.saving ||
        state.status == DietSetupStatus.saved) {
      return;
    }
    emit(state.copyWith(status: DietSetupStatus.saving));
    _analyticsRepository.analytic('DietView_SaveDietPlan_Start');
    try {
      await _nutritionRepository.saveDietPlan(plan);
      _analyticsRepository.analytic('DietView_SaveDietPlan_Success');
      if (!state.isFromSettings) {
        await _userRepository.updateUserFields(_uid, [
          UserField.didCompleteOnboarding(true),
        ]);
      }
      _analyticsRepository.info('DietView_Navigate');
      emit(state.copyWith(status: DietSetupStatus.saved));
    } on Object catch (error) {
      _analyticsRepository.severe('DietView_SaveDietPlan_Fail', error);
      emit(state.copyWith(status: DietSetupStatus.failure));
    }
  }

  @override
  Future<void> close() {
    _analyticsRepository.disappear(
      state.question.screen,
      _parameters(state.question),
    );
    return super.close();
  }
}
