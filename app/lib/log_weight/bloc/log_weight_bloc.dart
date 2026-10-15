import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart' show AppFormat;
import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/document_id.dart';
import 'package:compound/log_weight/logic/decimal_wheel_value.dart';
import 'package:compound/weight_metric/models/weight_metric.dart'
    show weighInsOf;
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

part 'log_weight_event.dart';
part 'log_weight_state.dart';

/// Logging a weigh-in (Swift `LogWeightPresenter`): opens on the latest
/// weigh-in in the profile's unit, saves a new manual entry, then sets the
/// profile's weight and weight unit to it.
class LogWeightBloc extends Bloc<LogWeightEvent, LogWeightState> {
  new({
    required this._bodyRepository,
    required this._userRepository,
    required this._analyticsRepository,
    required this._uid,
    this._now = DateTime.now,
    this._newId = newDocumentId,
  }) : super(LogWeightState(date: _now())) {
    on<LogWeightStarted>(_onStarted);
    on<LogWeightDateChanged>(_onDateChanged);
    on<LogWeightUnitChanged>(
      (event, emit) => emit(state.copyWith(unit: event.unit)),
    );
    on<LogWeightWholeChanged>(_onWholeChanged);
    on<LogWeightTenthsChanged>(_onTenthsChanged);
    on<LogWeightSaveRequested>(_onSaveRequested);
  }

  final BodyRepository _bodyRepository;
  final UserRepository _userRepository;
  final AnalyticsRepository _analyticsRepository;
  final String _uid;
  final DateTime Function() _now;
  final String Function() _newId;

  Future<void> _onStarted(
    LogWeightStarted event,
    Emitter<LogWeightState> emit,
  ) async {
    _analyticsRepository.trackScreenView(
      const AnalyticsEvent('LogWeightView_Appear'),
    );
    // Either missing leaves Swift's defaults: 70 kg, kilograms.
    UserModel? user;
    var measurements = const <BodyMeasurementEntry>[];
    try {
      user = await _userRepository.watchUser(_uid).first;
    } on Object catch (_) {}
    try {
      measurements = await _bodyRepository.watchMeasurements(_uid).first;
    } on Object catch (_) {}

    var next = state.copyWith(
      status: LogWeightStatus.ready,
      unit: user?.submittedWeightUnitPreference,
    );
    // The latest weigh-in, which Today and the charts show, else the weight
    // given at onboarding.
    final current =
        weighInsOf(measurements).lastOrNull?.weightKg ??
        user?.submittedWeightKilograms;
    if (current != null) next = next.withKilograms(current);
    emit(next);
  }

  /// Keeps the time of day the screen opened at, as Swift's date-only
  /// picker does.
  void _onDateChanged(
    LogWeightDateChanged event,
    Emitter<LogWeightState> emit,
  ) {
    final day = event.date;
    final time = state.date;
    emit(
      state.copyWith(
        date: DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
          time.second,
          time.millisecond,
          time.microsecond,
        ),
      ),
    );
  }

  void _onWholeChanged(
    LogWeightWholeChanged event,
    Emitter<LogWeightState> emit,
  ) => emit(switch (state.unit) {
    WeightUnitPreference.kilograms => state.withKilograms(
      DecimalWheelValue.combine(
        whole: event.whole,
        tenths: state.kilogramsTenths,
      ),
    ),
    WeightUnitPreference.pounds => state.withPounds(
      DecimalWheelValue.combine(whole: event.whole, tenths: state.poundsTenths),
    ),
  });

  void _onTenthsChanged(
    LogWeightTenthsChanged event,
    Emitter<LogWeightState> emit,
  ) => emit(switch (state.unit) {
    WeightUnitPreference.kilograms => state.withKilograms(
      DecimalWheelValue.combine(whole: state.kilograms, tenths: event.tenths),
    ),
    WeightUnitPreference.pounds => state.withPounds(
      DecimalWheelValue.combine(whole: state.pounds, tenths: event.tenths),
    ),
  });

  /// Saves the weigh-in, then the profile's weight and unit, as
  /// `LogWeightPresenter.saveWeight` does. Swift exports to Apple Health
  /// inside the save; that waits for M5.
  Future<void> _onSaveRequested(
    LogWeightSaveRequested event,
    Emitter<LogWeightState> emit,
  ) async {
    if (!state.isEditable) return;
    emit(state.copyWith(status: LogWeightStatus.saving));
    _analyticsRepository.trackEvent(
      const AnalyticsEvent('LogWeightView_Save_Start'),
    );
    final weightKg = state.weightKg;
    try {
      await _bodyRepository.saveMeasurement(
        BodyMeasurementEntry(
          id: _newId(),
          authorId: _uid,
          weightKg: weightKg,
          date: state.date,
          source: WeightSource.manual,
          dateCreated: _now(),
        ),
      );
      await _userRepository.updateUserFields(_uid, [
        UserField.submittedWeightKilograms(weightKg),
        UserField.submittedWeightUnitPreference(state.unit),
      ]);
      _analyticsRepository.trackEvent(
        const AnalyticsEvent('LogWeightView_Save_Success'),
      );
      emit(state.copyWith(status: LogWeightStatus.saved));
    } on Object catch (error) {
      _analyticsRepository.trackEvent(
        AnalyticsEvent(
          'LogWeightView_Save_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.severe,
        ),
      );
      emit(state.copyWith(status: LogWeightStatus.failure));
    }
  }

  @override
  Future<void> close() {
    _analyticsRepository.trackEvent(
      const AnalyticsEvent('LogWeightView_Disappear'),
    );
    return super.close();
  }
}
