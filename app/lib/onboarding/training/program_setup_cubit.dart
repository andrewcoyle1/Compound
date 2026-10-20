import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:program_repository/program_repository.dart';
import 'package:user_repository/user_repository.dart';

enum ProgramSetupStatus { idle, starting, started, failure }

/// Workouts in a week of [mesocycle]: its day plans with exercises
/// (`CreateMesocyclePresenter.workoutsPerMicrocycle`).
int workoutsPerMicrocycle(Mesocycle mesocycle) =>
    mesocycle.workoutTemplates.where((day) => day.exercises.isNotEmpty).length;

final class const ProgramSetupState({
  /// The shipped program matched to the user's exercise frequency.
  final Mesocycle? recommended,

  /// Every other shipped program, fewest workouts a week first.
  final List<Mesocycle> others = const [],
  final String? selectedId,
  final ProgramSetupStatus status = ProgramSetupStatus.idle,
}) extends Equatable {
  Mesocycle? get selected => [
    ?recommended,
    ...others,
  ].where((program) => program.id == selectedId).firstOrNull;

  ProgramSetupState copyWith({
    String? selectedId,
    ProgramSetupStatus? status,
  }) => ProgramSetupState(
    recommended: recommended,
    others: others,
    selectedId: selectedId ?? this.selectedId,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => [recommended, others, selectedId, status];
}

/// The program step (Swift `CreateMesocyclePresenter` and
/// `PrebuiltMesocycleDetailPresenter.onStartPressed`): the shipped programs,
/// the one matched to how often the user exercises first and chosen, and
/// Start, which copies it as the user's own and makes it active
/// ([TrainingSetupService.startPrebuiltMesocycle]). Build My Own opens the
/// create flow, whose Activate moves onboarding on.
class ProgramSetupCubit extends Cubit<ProgramSetupState> {
  new({
    required this._trainingSetupService,
    required this._analyticsRepository,
    required UserModel profile,
    required List<Mesocycle> programs,
  }) : _uid = profile.userId,
       super(_initial(profile, programs)) {
    _analyticsRepository.appear(_screen);
  }

  static const _screen = 'CreateProgramView';

  static ProgramSetupState _initial(
    UserModel profile,
    List<Mesocycle> programs,
  ) {
    final id = recommendedProgramId(profile.submittedExerciseFrequency);
    final recommended = programs.where((p) => p.id == id).firstOrNull;
    final others = programs.where((p) => p.id != recommended?.id).toList()
      ..sort((a, b) {
        final byCount = workoutsPerMicrocycle(a)
            .compareTo(workoutsPerMicrocycle(b));
        return byCount != 0 ? byCount : a.name.compareTo(b.name);
      });
    return ProgramSetupState(
      recommended: recommended,
      others: others,
      selectedId: recommended?.id,
    );
  }

  final TrainingSetupService _trainingSetupService;
  final AnalyticsRepository _analyticsRepository;
  final String _uid;

  void programSelected(Mesocycle program) {
    _analyticsRepository.analytic('CreateProgramView_Program_Pressed', {
      'program_id': program.id,
      'is_recommended': program.id == state.recommended?.id,
    });
    emit(state.copyWith(selectedId: program.id));
  }

  /// Build My Own: the name, icon and design steps follow.
  void buildOwnPressed() =>
      _analyticsRepository.analytic('CreateProgramView_BuildOwn_Pressed');

  /// Starts the chosen program. The AppBloc then moves on to the diet.
  Future<void> start() async {
    final program = state.selected;
    if (program == null ||
        state.status == ProgramSetupStatus.starting ||
        state.status == ProgramSetupStatus.started) {
      return;
    }
    emit(state.copyWith(status: ProgramSetupStatus.starting));
    final parameters = {'program_id': program.id};
    _analyticsRepository.analytic(
      'PrebuiltProgramDetailView_Start_Start',
      parameters,
    );
    try {
      await _trainingSetupService.startPrebuiltMesocycle(_uid, program);
      _analyticsRepository.analytic(
        'PrebuiltProgramDetailView_Start_Success',
        parameters,
      );
      emit(state.copyWith(status: ProgramSetupStatus.started));
    } on Object catch (error) {
      _analyticsRepository.severe(
        'PrebuiltProgramDetailView_Start_Fail',
        error,
        parameters,
      );
      emit(state.copyWith(status: ProgramSetupStatus.failure));
    }
  }

  @override
  Future<void> close() {
    _analyticsRepository.disappear(_screen);
    return super.close();
  }
}
