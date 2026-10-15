import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

/// Whether a region measures in metric, as Swift's
/// `locale.measurementSystem == .metric` decides: the United States,
/// Liberia and Myanmar use US units and the United Kingdom its own, so all
/// four start on pounds, inches and miles. No region counts as metric.
bool usesMetric(String? countryCode) =>
    !const {'US', 'LR', 'MM', 'GB'}.contains(countryCode?.toUpperCase());

/// The three unit preferences on the Units screen.
class const UnitsState({
  required final WeightUnitPreference weight,
  required final LengthUnitPreference length,
  required final DistanceUnitPreference distance,

  /// The last save failed to start.
  final bool saveFailed = false,
}) extends Equatable {
  /// What [user] chose, or, for what they never chose, the region's
  /// system. A missing distance follows the length, which was chosen first
  /// (`UnitsPresenter.init`).
  factory initial(UserModel? user, {required bool isMetric}) {
    final length =
        user?.submittedLengthUnitPreference ??
        (isMetric
            ? LengthUnitPreference.centimeters
            : LengthUnitPreference.inches);
    return UnitsState(
      weight:
          user?.submittedWeightUnitPreference ??
          (isMetric
              ? WeightUnitPreference.kilograms
              : WeightUnitPreference.pounds),
      length: length,
      distance:
          user?.submittedDistanceUnitPreference ??
          (length == LengthUnitPreference.centimeters
              ? DistanceUnitPreference.kilometers
              : DistanceUnitPreference.miles),
    );
  }

  @override
  List<Object> get props => [weight, length, distance, saveFailed];
}

/// The Units screen (Swift `UnitsPresenter`): every change writes all three
/// preferences in one update, as `UserManager.updateUnitPreferences` does,
/// so there is no Save button.
class UnitsCubit extends Cubit<UnitsState> {
  new({
    required this._users,
    required this._analytics,
    required this._uid,
    required UnitsState initial,
  }) : super(initial);

  final UserRepository _users;
  final AnalyticsRepository _analytics;
  final String _uid;

  /// `UnitsView_Appear`.
  void appeared() => _analytics.appear('UnitsView');

  /// `UnitsView_Disappear`.
  void disappeared() => _analytics.disappear('UnitsView');

  /// Weight: kilograms or pounds.
  Future<void> weightChanged(WeightUnitPreference weight) => _save(
    UnitsState(weight: weight, length: state.length, distance: state.distance),
  );

  /// Height and every body measurement.
  Future<void> lengthChanged(LengthUnitPreference length) => _save(
    UnitsState(weight: state.weight, length: length, distance: state.distance),
  );

  /// Distance: kilometres or miles.
  Future<void> distanceChanged(DistanceUnitPreference distance) => _save(
    UnitsState(weight: state.weight, length: state.length, distance: distance),
  );

  Future<void> _save(UnitsState next) async {
    emit(next);
    _analytics.analytic('UnitsView_Save_Start');
    try {
      await _users.updateUserFields(_uid, [
        UserField.submittedLengthUnitPreference(next.length),
        UserField.submittedWeightUnitPreference(next.weight),
        UserField.submittedDistanceUnitPreference(next.distance),
      ]);
      _analytics.analytic('UnitsView_Save_Success');
    } on Object catch (error) {
      _analytics.severe('UnitsView_Save_Fail', error);
      if (!isClosed) {
        emit(
          UnitsState(
            weight: state.weight,
            length: state.length,
            distance: state.distance,
            saveFailed: true,
          ),
        );
      }
    }
  }
}
