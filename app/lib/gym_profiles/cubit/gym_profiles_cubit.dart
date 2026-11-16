import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// What the last favourite came to; a failure is reported once.
enum GymProfilesStatus {
  /// Nothing to report.
  idle,

  /// "Unable to set your usual gym".
  favouriteFailure,
}

/// The gym list's writes (Swift `GymProfilesPresenter`): deleting a gym
/// once its Undo window has closed, and making one the usual gym. The gyms
/// themselves come from the training library.
class GymProfilesCubit extends Cubit<GymProfilesStatus> {
  new({
    required this._uid,
    required this._library,
    required this._setup,
    required this._analytics,
  }) : super(GymProfilesStatus.idle) {
    _analytics.appear(_screen);
  }

  static const _screen = 'GymProfilesView';

  final String _uid;
  final TrainingLibraryRepository _library;
  final TrainingSetupService _setup;
  final AnalyticsRepository _analytics;

  /// Deletes [gym] and the equipment set up in it.
  /// Deletes [gym] for good. It runs once the Undo window has closed, when
  /// this cubit may have gone, so it only writes and records, and rethrows
  /// a failure for the snack bar to report.
  Future<void> delete(GymProfileModel gym) async {
    _analytics.analytic('${_screen}_DeleteProfile_Start');
    try {
      await _library.deleteGymProfile(_uid, gym.id);
      _analytics.analytic('${_screen}_DeleteProfile_Success');
    } on Object catch (error) {
      _analytics.severe('${_screen}_DeleteProfile_Fail', error);
      rethrow;
    }
  }

  /// The Undo after deleting [gym].
  void deleteUndone(GymProfileModel gym) =>
      _analytics.analytic('${_screen}_DeleteProfile_Undo');

  /// Makes [gym] the usual one.
  Future<void> favourite(GymProfileModel gym) async {
    emit(GymProfilesStatus.idle);
    _analytics.analytic('${_screen}_FavouriteGymProfile_Start');
    try {
      await _setup.setFavouriteGymProfile(_uid, gym.id);
      _analytics.analytic('${_screen}_FavouriteGymProfile_Success');
    } on Object catch (error) {
      _analytics.severe('${_screen}_FavouriteGymProfile_Fail', error);
      if (!isClosed) emit(GymProfilesStatus.favouriteFailure);
    }
  }

  @override
  Future<void> close() {
    _analytics.disappear(_screen);
    return super.close();
  }
}
