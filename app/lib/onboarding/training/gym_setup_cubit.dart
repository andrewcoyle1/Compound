import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show GymProfileModel;
import 'package:user_repository/user_repository.dart';

final class const GymSetupState({final String name = ''}) extends Equatable {
  /// As Swift's `canSave`: any name, untrimmed.
  bool get canSave => name.isNotEmpty;

  @override
  List<Object?> get props => [name];
}

/// Naming a new gym (Swift `CreateGymProfilePresenter`), in onboarding's
/// gym step and from Choose Gym Profile. Continue hands over a new gym with
/// the whole catalogue set up for the user's weight unit, which the gym
/// editor then sets up, saves and makes the usual gym.
class GymSetupCubit extends Cubit<GymSetupState> {
  new({
    required this._analyticsRepository,
    required this._profile,
    this._now = DateTime.now,
    this._newId = newUuid,
    this._kilogramStackName = 'Kilogram stack',
  }) : super(const GymSetupState()) {
    _analyticsRepository.appear(_screen);
  }

  static const _screen = 'CreateGymProfileView';

  final AnalyticsRepository _analyticsRepository;
  final UserModel _profile;
  final DateTime Function() _now;
  final String Function() _newId;
  final String _kilogramStackName;

  void nameChanged(String name) => emit(GymSetupState(name: name));

  /// The new gym under the typed name, or null until there is one.
  GymProfileModel? draft() => state.canSave
      ? newGymProfile(
          authorId: _profile.userId,
          name: state.name,
          now: _now(),
          weightUnit: _profile.submittedWeightUnitPreference,
          newId: _newId,
          kilogramStackName: _kilogramStackName,
        )
      : null;

  @override
  Future<void> close() {
    _analyticsRepository.disappear(_screen);
    return super.close();
  }
}
