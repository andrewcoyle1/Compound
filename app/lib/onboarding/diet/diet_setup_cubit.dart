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
/// standard one.
enum DietQuestion {
  intro('CustomisingDietProgramView'),
  preferredDiet('PreferredDietView'),
  distribution('CalorieDistributionView'),
  protein('ProteinIntakeView'),
  plan('DietPlanView');

  new(this.screen);

  final String screen;

  /// The intro logs no parameters; the rest say they are onboarding.
  Map<String, Object?>? get parameters =>
      this == intro ? null : onboardingParameters;
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
  ];
}

/// The diet step (Swift `CustomisingDietProgramPresenter` through
/// `DietPlanPresenter`): use the recommended answers, or answer the diet,
/// distribution and protein questions; then the plan is saved and
/// onboarding marked complete, which the AppBloc follows to the tabs.
class DietSetupCubit extends Cubit<DietSetupState> {
  new({
    required this._nutritionRepository,
    required this._programRepository,
    required this._bodyRepository,
    required this._userRepository,
    required this._analyticsRepository,
    required this._profile,
    this._now = DateTime.now,
  }) : super(DietSetupState(gender: _profile.submittedGender)) {
    _analyticsRepository.appear(
      state.question.screen,
      state.question.parameters,
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
      ..disappear(state.question.screen, state.question.parameters)
      ..appear(question.screen, question.parameters);
    emit(state.copyWith(question: question, status: DietSetupStatus.ready));
  }

  /// Back one question; the plan reached by "Use Recommended Plan" goes back
  /// to the intro. False on the intro.
  bool back() {
    if (state.question == DietQuestion.intro) return false;
    _go(
      state.question == DietQuestion.plan && _usedRecommended
          ? DietQuestion.intro
          : DietQuestion.values[state.question.index - 1],
    );
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

  /// On to the distribution, opening on the plan's own answer, else the
  /// one the mesocycle suggests (`CalorieDistributionPresenter.init`).
  void dietContinued() {
    _analyticsRepository.info('Onboarding_PrefDiet_Navigate');
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
  /// `DietPlanPresenter.navigate` does for onboarding.
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
      await _userRepository.updateUserFields(_uid, [
        UserField.didCompleteOnboarding(true),
      ]);
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
      state.question.parameters,
    );
    return super.close();
  }
}
