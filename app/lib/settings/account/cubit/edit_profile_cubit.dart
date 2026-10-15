import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

part 'edit_profile_state.dart';

/// Centimetres in an inch, as `UnitConversion` converts lengths.
const centimetresPerInch = 2.54;

/// Edit Profile (Swift `EditProfilePresenter`): the profile's names, date of
/// birth, sex, height and the onboarding answers, saved together by Save;
/// and the privacy switch, written the moment it flips.
///
/// Save writes only what Swift writes, each under its own key: the trimmed
/// names, then every other field only when it has a value, and the height
/// only when it differs from what was shown. Writes complete once Firestore
/// has them locally, so Save closes the screen offline too.
class EditProfileCubit extends Cubit<EditProfileState> {
  /// Opens on [user]'s stored profile, or blank when there is none.
  new({
    required this._userRepository,
    required this._analytics,
    required UserModel? user,
  }) : super(EditProfileState.from(user));

  final UserRepository _userRepository;
  final AnalyticsRepository _analytics;

  static const _screen = 'AccountView';

  /// `AccountView_Appear`, as a screen view.
  void appeared() => _analytics.appear(_screen);

  /// `AccountView_Disappear`.
  void disappeared() => _analytics.disappear(_screen);

  void firstNameChanged(String value) =>
      emit(state.copyWith(firstName: value, status: EditProfileStatus.editing));

  void lastNameChanged(String value) =>
      emit(state.copyWith(lastName: value, status: EditProfileStatus.editing));

  void dateOfBirthChanged(DateTime value) => emit(
    state.copyWith(dateOfBirth: () => value, status: EditProfileStatus.editing),
  );

  void genderChanged(Gender? value) => emit(
    state.copyWith(gender: () => value, status: EditProfileStatus.editing),
  );

  /// The height as typed, in [EditProfileState.heightUnit]; null when the
  /// field is empty or unreadable.
  void heightChanged(double? value) => emit(
    state.copyWith(height: () => value, status: EditProfileStatus.editing),
  );

  void cardioFitnessLevelChanged(CardioFitnessLevel? value) => emit(
    state.copyWith(
      cardioFitnessLevel: () => value,
      status: EditProfileStatus.editing,
    ),
  );

  void exerciseFrequencyChanged(ExerciseFrequency? value) => emit(
    state.copyWith(
      exerciseFrequency: () => value,
      status: EditProfileStatus.editing,
    ),
  );

  void activityLevelChanged(ActivityLevel? value) => emit(
    state.copyWith(
      activityLevel: () => value,
      status: EditProfileStatus.editing,
    ),
  );

  /// `AccountView_Cancel_Pressed`; the view closes the screen.
  void cancelPressed() => _analytics.analytic('AccountView_Cancel_Pressed');

  /// Writes `is_private` at once, as a switch should. A write that cannot
  /// start puts the switch back and says so.
  Future<void> privacyChanged({required bool isPrivate}) async {
    final uid = state.uid;
    if (uid == null) return;
    final parameters = {'is_private': isPrivate};
    _analytics
      ..analytic('AccountView_Privacy_Toggle', parameters)
      ..analytic('AccountView_UpdatePrivacy_Start', parameters);
    final previous = state.isPrivate;
    emit(state.copyWith(isPrivate: isPrivate));
    try {
      await _userRepository.updateUserFields(uid, [
        UserField.isPrivate(isPrivate),
      ]);
      _analytics.analytic('AccountView_UpdatePrivacy_Success', parameters);
    } on Object catch (error) {
      _analytics.severe('AccountView_UpdatePrivacy_Fail', error);
      emit(
        state.copyWith(
          isPrivate: previous,
          status: EditProfileStatus.privacyFailure,
        ),
      );
    }
  }

  /// Saves the profile, then reports [EditProfileStatus.saved] for the view
  /// to close. Nothing is written without a first name.
  Future<void> savePressed() async {
    final uid = state.uid;
    if (uid == null || !state.canSave) return;
    emit(state.copyWith(status: EditProfileStatus.saving));
    _analytics.analytic('AccountView_SaveProfile_Start');
    try {
      await _userRepository.updateUserFields(uid, state.fieldsToSave);
      _analytics
        ..analytic('profile_edit_save_success')
        ..analytic('AccountView_SaveProfile_Success');
      emit(state.copyWith(status: EditProfileStatus.saved));
    } on Object catch (error) {
      _analytics
        ..analytic('profile_edit_save_failed', {'error': '$error'})
        ..severe('AccountView_SaveProfile_Fail', error);
      emit(state.copyWith(status: EditProfileStatus.saveFailure));
    }
  }
}
