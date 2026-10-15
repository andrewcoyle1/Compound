import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show GymProfileModel;
import 'package:user_repository/user_repository.dart';

enum GymSetupStatus { idle, saving, saved, failure }

final class const GymSetupState({
  final String name = '',
  final GymSetupStatus status = GymSetupStatus.idle,
}) extends Equatable {
  /// As Swift's `canSave`: any name, untrimmed.
  bool get canSave => name.isNotEmpty;

  @override
  List<Object?> get props => [name, status];
}

/// The gym step, cut down to naming it (Swift `CreateGymProfilePresenter`
/// then `GymProfilePresenter.onContinuePressed`): a new gym with the whole
/// catalogue set up for the user's weight unit is saved, then made the
/// usual gym. A failure to make it the usual one is logged and passed over,
/// as in Swift, which leaves this step to be asked again. Editing the
/// equipment waits for the gym editor (M5).
class GymSetupCubit extends Cubit<GymSetupState> {
  new({
    required this._trainingSetupService,
    required this._analyticsRepository,
    required this._profile,
    this._now = DateTime.now,
    this._newId = newUuid,
    this._untitledName = 'Untitled Gym Profile',
    this._kilogramStackName = 'Kilogram stack',
  }) : super(const GymSetupState()) {
    _analyticsRepository.appear(_screen);
  }

  static const _screen = 'CreateGymProfileView';

  final TrainingSetupService _trainingSetupService;
  final AnalyticsRepository _analyticsRepository;
  final UserModel _profile;
  final DateTime Function() _now;
  final String Function() _newId;
  final String _untitledName;
  final String _kilogramStackName;

  void nameChanged(String name) =>
      emit(GymSetupState(name: name, status: state.status));

  Future<void> save() async {
    if (!state.canSave ||
        state.status == GymSetupStatus.saving ||
        state.status == GymSetupStatus.saved) {
      return;
    }
    emit(GymSetupState(name: state.name, status: GymSetupStatus.saving));
    final uid = _profile.userId;
    final GymProfileModel saved;
    try {
      _analyticsRepository.analytic('GymProfileView_Save_Start');
      saved = await _trainingSetupService.saveGymProfile(
        newGymProfile(
          authorId: uid,
          name: state.name,
          now: _now(),
          weightUnit: _profile.submittedWeightUnitPreference,
          newId: _newId,
          kilogramStackName: _kilogramStackName,
        ),
        untitledName: _untitledName,
      );
      _analyticsRepository.analytic('GymProfileView_Save_Success');
    } on Object catch (error) {
      _analyticsRepository.severe('GymProfileView_Save_Fail', error);
      emit(GymSetupState(name: state.name, status: GymSetupStatus.failure));
      return;
    }
    _analyticsRepository.analytic('GymProfileView_FavouriteGymProfile_Start');
    try {
      await _trainingSetupService.setFavouriteGymProfile(uid, saved.id);
      _analyticsRepository.analytic(
        'GymProfileView_FavouriteGymProfile_Success',
      );
    } on Object catch (_) {
      // Swift logs this one with no parameters, as an analytic event.
      _analyticsRepository.analytic('GymProfileView_FavouriteGymProfile_Fail');
    }
    emit(GymSetupState(name: state.name, status: GymSetupStatus.saved));
  }

  @override
  Future<void> close() {
    _analyticsRepository.disappear(_screen);
    return super.close();
  }
}
