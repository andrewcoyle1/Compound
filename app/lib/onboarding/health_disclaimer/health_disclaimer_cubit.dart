import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

/// Where the consent save has got to.
enum HealthDisclaimerStatus { idle, saving, failure }

/// The two acceptances the disclaimer screen asks for.
final class const HealthDisclaimerState({
  final bool acceptedTerms = false,
  final bool acceptedPrivacy = false,
  final HealthDisclaimerStatus status = HealthDisclaimerStatus.idle,
}) extends Equatable {
  bool get canContinue => acceptedTerms && acceptedPrivacy;

  HealthDisclaimerState copyWith({
    bool? acceptedTerms,
    bool? acceptedPrivacy,
    HealthDisclaimerStatus? status,
  }) => HealthDisclaimerState(
    acceptedTerms: acceptedTerms ?? this.acceptedTerms,
    acceptedPrivacy: acceptedPrivacy ?? this.acceptedPrivacy,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => [acceptedTerms, acceptedPrivacy, status];
}

/// The health disclaimer (Swift `HealthDisclaimerPresenter`): both
/// acceptances are stamped with the current versions and one time, which
/// [inferredOnboardingStep] then compares. The AppBloc moves on to the goal.
class HealthDisclaimerCubit extends Cubit<HealthDisclaimerState> {
  new({
    required this._userRepository,
    required this._analyticsRepository,
    required this._uid,
    this._now = DateTime.now,
  }) : super(const HealthDisclaimerState()) {
    _analyticsRepository.appear(_screen);
  }

  static const _screen = 'HealthDisclaimerView';

  final UserRepository _userRepository;
  final AnalyticsRepository _analyticsRepository;
  final String _uid;
  final DateTime Function() _now;

  void termsChanged({required bool accepted}) =>
      emit(state.copyWith(acceptedTerms: accepted));

  void privacyChanged({required bool accepted}) =>
      emit(state.copyWith(acceptedPrivacy: accepted));

  /// `UserManager.updateHealthConsents`: both versions and both dates in
  /// one update.
  Future<void> accept() async {
    if (!state.canContinue || state.status == HealthDisclaimerStatus.saving) {
      return;
    }
    emit(state.copyWith(status: HealthDisclaimerStatus.saving));
    const versions = {
      'disclaimer_version': currentHealthDisclaimerVersion,
      'privacy_version': currentHealthPrivacyPolicyVersion,
    };
    final now = _now();
    _analyticsRepository.analytic('consent_health_confirm_start', versions);
    try {
      await _userRepository.updateUserFields(_uid, [
        UserField.acceptedHealthDisclaimerVersion(
          currentHealthDisclaimerVersion,
        ),
        UserField.acceptedHealthDisclaimerDate(now),
        UserField.acceptedHealthPrivacyPolicyVersion(
          currentHealthPrivacyPolicyVersion,
        ),
        UserField.acceptedHealthPrivacyPolicyDate(now),
      ]);
      _analyticsRepository
        ..analytic('consent_health_confirm_success', {
          ...versions,
          'accepted_at': now,
        })
        ..info('HealthDisclaimer_Navigate');
      emit(state.copyWith(status: HealthDisclaimerStatus.idle));
    } on Object catch (error) {
      _analyticsRepository.severe(
        'consent_health_confirm_fail',
        error,
        versions,
      );
      emit(state.copyWith(status: HealthDisclaimerStatus.failure));
    }
  }

  @override
  Future<void> close() {
    _analyticsRepository.disappear(_screen);
    return super.close();
  }
}
