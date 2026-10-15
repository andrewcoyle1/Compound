import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/document_id.dart';
import 'package:compound/log_weight/logic/decimal_wheel_value.dart';
import 'package:compound/nutrition/logic/meal_day.dart' show startOfDay;
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/progress/logic/body_metrics.dart';
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

part 'log_measurement_event.dart';
part 'log_measurement_state.dart';

/// Logging one circumference (Swift `LogMeasurementPresenter`): opens on
/// the latest reading of it in the profile's length unit, and saves it onto
/// the day's entry, or a new one when the day has none, so logging twice
/// in a day updates the same entry.
class LogMeasurementBloc
    extends Bloc<LogMeasurementEvent, LogMeasurementState> {
  new({
    required this._bodyRepository,
    required this._userRepository,
    required this._analyticsRepository,
    required this._uid,
    required BodyMeasurementKind kind,
    this._now = DateTime.now,
    this._newId = newDocumentId,
  }) : super(LogMeasurementState.initial(kind, _now())) {
    on<LogMeasurementStarted>(_onStarted);
    on<LogMeasurementDateChanged>(_onDateChanged);
    on<LogMeasurementUnitChanged>(
      (event, emit) => emit(state.copyWith(unit: event.unit)),
    );
    on<LogMeasurementWholeChanged>(
      (event, emit) => emit(state.withWhole(event.whole)),
    );
    on<LogMeasurementTenthsChanged>(
      (event, emit) => emit(state.withTenths(event.tenths)),
    );
    on<LogMeasurementSaveRequested>(_onSaveRequested);
  }

  final BodyRepository _bodyRepository;
  final UserRepository _userRepository;
  final AnalyticsRepository _analyticsRepository;
  final String _uid;
  final DateTime Function() _now;
  final String Function() _newId;

  /// The entries read when the screen opened, for the day's entry.
  List<BodyMeasurementEntry> _measurements = const [];

  Map<String, Object?> get _parameters => {'measurement': state.kind.name};

  Future<void> _onStarted(
    LogMeasurementStarted event,
    Emitter<LogMeasurementState> emit,
  ) async {
    _analyticsRepository.appear('LogMeasurementView', _parameters);
    // Either missing leaves Swift's defaults: the kind's, in centimetres.
    UserModel? user;
    try {
      user = await _userRepository.watchUser(_uid).first;
    } on Object catch (_) {}
    try {
      _measurements = await _bodyRepository.watchMeasurements(_uid).first;
    } on Object catch (_) {}
    var next = state.copyWith(
      status: LogMeasurementStatus.ready,
      unit: user?.submittedLengthUnitPreference,
    );
    final latest = entriesOf(_measurements, state.kind.valueOf).lastOrNull;
    if (latest != null) next = next.withCentimetres(latest.value);
    emit(next);
  }

  /// Keeps the time of day the screen opened at, as Swift's date-only
  /// picker does.
  void _onDateChanged(
    LogMeasurementDateChanged event,
    Emitter<LogMeasurementState> emit,
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

  /// Saves the reading onto the first live entry on the chosen day, else a
  /// new manual entry (`LogMeasurementPresenter.saveMeasurement`).
  Future<void> _onSaveRequested(
    LogMeasurementSaveRequested event,
    Emitter<LogMeasurementState> emit,
  ) async {
    if (!state.isEditable) return;
    emit(state.copyWith(status: LogMeasurementStatus.saving));
    _analyticsRepository.analytic('LogMeasurementView_Save_Start', _parameters);
    final day = startOfDay(state.date);
    final base =
        _measurements
            .where(
              (entry) =>
                  entry.deletedAt == null && startOfDay(entry.date) == day,
            )
            .firstOrNull ??
        BodyMeasurementEntry(
          id: _newId(),
          authorId: _uid,
          date: state.date,
          source: WeightSource.manual,
          dateCreated: _now(),
        );
    try {
      await _bodyRepository.saveMeasurement(
        state.kind.update(base, state.centimetresValue),
      );
      _analyticsRepository.analytic(
        'LogMeasurementView_Save_Success',
        _parameters,
      );
      emit(state.copyWith(status: LogMeasurementStatus.saved));
    } on Object catch (error) {
      _analyticsRepository.severe(
        'LogMeasurementView_Save_Fail',
        error,
        _parameters,
      );
      emit(state.copyWith(status: LogMeasurementStatus.failure));
    }
  }

  @override
  Future<void> close() {
    if (!isClosed) {
      _analyticsRepository.disappear('LogMeasurementView', _parameters);
    }
    return super.close();
  }
}
