import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/document_id.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:compound/log_weight/bloc/log_weight_bloc.dart'
    show LogWeightState;
import 'package:compound/weight_metric/models/weight_metric.dart'
    show weighInsOf;
import 'package:compound_maths/compound_maths.dart' show TargetProposal;
import 'package:equatable/equatable.dart';
import 'package:health_repository/health_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:user_repository/user_repository.dart';

part 'weekly_check_in_event.dart';
part 'weekly_check_in_state.dart';

/// The weekly check-in (Swift `CheckInPresenter`): one bloc driving an
/// ordered list of steps.
///
/// The steps are worked out once, from the first data that arrives, and do
/// not change: a list that grew a step halfway through would move the
/// finish line under someone walking towards it. The engine's figures stay
/// live, so the last step's proposal reflects the answers just saved.
class WeeklyCheckInBloc extends Bloc<WeeklyCheckInEvent, WeeklyCheckInState> {
  new({
    required this._users,
    required this._nutrition,
    required this._body,
    required this._checkIns,
    required this._programs,
    required this._analytics,
    required this._dismissals,
    required this._uid,
    required DateTime weekStart,
    this._now = DateTime.now,
    this._newId = newDocumentId,
    this._health,
  }) : super(
         WeeklyCheckInState(
           weekStart: weekStart,
           weighIn: LogWeightState(date: _now()),
         ),
       ) {
    on<WeeklyCheckInStarted>(_onStarted);
    on<WeeklyCheckInPartialToggled>(
      (event, emit) => emit(
        state.copyWith(
          partialRows: _toggled(state.partialRows, event.dayKey, on: event.on),
        ),
      ),
    );
    on<WeeklyCheckInFastingToggled>(
      (event, emit) => emit(
        state.copyWith(
          fastingRows: _toggled(state.fastingRows, event.dayKey, on: event.on),
        ),
      ),
    );
    on<WeeklyCheckInUnitChanged>(
      (event, emit) => emit(
        state.copyWith(weighIn: state.weighIn.copyWith(unit: event.unit)),
      ),
    );
    on<WeeklyCheckInWholeChanged>(
      (event, emit) =>
          emit(state.copyWith(weighIn: state.weighIn.withWhole(event.whole))),
    );
    on<WeeklyCheckInTenthsChanged>(
      (event, emit) =>
          emit(state.copyWith(weighIn: state.weighIn.withTenths(event.tenths))),
    );
    on<WeeklyCheckInContinuePressed>(_onContinuePressed);
    on<WeeklyCheckInLogWeightPressed>(_onLogWeightPressed);
    on<WeeklyCheckInSkipWeighInPressed>(_onSkipWeighInPressed);
    on<WeeklyCheckInStartBreakPressed>(_onStartBreakPressed);
    on<WeeklyCheckInEndBreakPressed>(_onEndBreakPressed);
    on<WeeklyCheckInAcceptPressed>(_onAcceptPressed);
    on<WeeklyCheckInDonePressed>(_onDonePressed);
    on<WeeklyCheckInDismissPressed>(
      (event, emit) => _track('CheckInView_Dismissed', {
        'step': state.currentStep?.name ?? 'none',
      }),
    );
  }

  final UserRepository _users;
  final NutritionRepository _nutrition;
  final BodyRepository _body;

  /// Where the weigh-in is also saved, first; none in tests.
  final HealthRepository? _health;
  final CheckInRepository _checkIns;
  final ProgramRepository _programs;
  final AnalyticsRepository _analytics;
  final ProposalDismissals _dismissals;
  final String _uid;
  final DateTime Function() _now;
  final String Function() _newId;

  /// The data the figures were last worked out from.
  ExpenditureSnapshot? _snapshot;

  void _track(
    String name, [
    Map<String, Object?>? parameters,
    LogType type = LogType.analytic,
  ]) => _analytics.trackEvent(
    AnalyticsEvent(name, parameters: parameters, type: type),
  );

  void _fail(String name, Object error, [Map<String, Object?>? parameters]) =>
      _track(name, {
        ...?parameters,
        'error_description': '$error',
      }, LogType.severe);

  static List<CheckInDay> _toggled(
    List<CheckInDay> rows,
    String dayKey, {
    required bool on,
  }) => [
    for (final row in rows)
      if (row.dayKey == dayKey) row.toggled(on: on) else row,
  ];

  Future<void> _onStarted(
    WeeklyCheckInStarted event,
    Emitter<WeeklyCheckInState> emit,
  ) => emit.forEach(
    watchExpenditure(
      uid: _uid,
      users: _users,
      nutrition: _nutrition,
      body: _body,
      checkIns: _checkIns,
    ),
    onData: (snapshot) {
      _snapshot = snapshot;
      final now = _now();
      final figures = ExpenditureFigures.of(
        snapshot,
        now,
        dismissedKcal: _dismissals.of(_uid),
      );
      if (state.flow != null) return state.copyWith(figures: figures);
      return _built(snapshot, figures, now);
    },
    onError: (_, _) => state.flow == null
        ? state.copyWith(status: WeeklyCheckInStatus.failure)
        : state,
  );

  /// The flow from the first data (`buildWeek`, `buildSteps`,
  /// `loadWeightInput`), with the screen's appear and first step tracked.
  WeeklyCheckInState _built(
    ExpenditureSnapshot snapshot,
    ExpenditureFigures figures,
    DateTime now,
  ) {
    final flow = CheckInFlow(
      now: now,
      settings: snapshot.settings,
      expenditureKcal: figures.current.kcal,
      meals: snapshot.meals,
      annotations: snapshot.annotations,
      measurements: snapshot.measurements,
      openLoggingBreak: figures.openLoggingBreak,
    );
    var weighIn = state.weighIn;
    final user = snapshot.user;
    if (user != null) {
      weighIn = weighIn.copyWith(unit: user.submittedWeightUnitPreference);
      final latest =
          weighInsOf(snapshot.measurements).lastOrNull?.weightKg ??
          user.submittedWeightKilograms;
      if (latest != null) weighIn = weighIn.withKilograms(latest);
    }
    _analytics.trackScreenView(
      AnalyticsEvent(
        'CheckInView_Appear',
        parameters: {
          'check_in_week_start': state.weekStart,
          'check_in_steps': flow.steps.map((step) => step.name).join(','),
          'check_in_step_count': flow.steps.length,
        },
      ),
    );
    _track('CheckInView_Step_Shown', {'step': flow.steps.first.name});
    return state.copyWith(
      status: WeeklyCheckInStatus.ready,
      flow: flow,
      partialRows: flow.partialRows,
      fastingRows: flow.fastingRows,
      weighIn: weighIn,
      figures: figures,
    );
  }

  bool get _busy => state.isSaving || state.currentStep == null;

  void _stepCompleted(CheckInStep step, String outcome) => _track(
    'CheckInView_Step_Completed',
    {'step': step.name, 'check_in_step_outcome': outcome},
  );

  Future<void> _onContinuePressed(
    WeeklyCheckInContinuePressed event,
    Emitter<WeeklyCheckInState> emit,
  ) async {
    if (_busy) return;
    final step = state.currentStep!;
    final flow = state.flow!;
    _stepCompleted(step, 'continue');
    final now = _now();
    switch (step) {
      case CheckInStep.partialLogging:
        final annotations = flow.partialAnnotations(
          state.partialRows,
          uid: _uid,
          now: now,
        );
        await _perform(
          emit,
          'save_annotations',
          () => _checkIns.saveDayAnnotations(_uid, annotations),
        );
      case CheckInStep.fasting:
        final annotations = flow.fastingAnnotations(
          state.fastingRows,
          uid: _uid,
          now: now,
        );
        await _perform(
          emit,
          'save_annotations',
          () => _checkIns.saveDayAnnotations(_uid, annotations),
        );
      case CheckInStep.introduction ||
          CheckInStep.weighIn ||
          CheckInStep.loggingBreak ||
          CheckInStep.programUpdate:
        await _advance(emit);
    }
  }

  /// Saves the weigh-in, then the profile's weight and unit, as Log Weight
  /// does.
  Future<void> _onLogWeightPressed(
    WeeklyCheckInLogWeightPressed event,
    Emitter<WeeklyCheckInState> emit,
  ) async {
    if (_busy) return;
    _stepCompleted(CheckInStep.weighIn, 'logged');
    emit(state.copyWith(isSaving: true));
    _track('CheckInView_LogWeight_Start');
    final weighIn = state.weighIn;
    final now = _now();
    try {
      // Through Health first when there is one, as Log Weight saves.
      await (_health?.saveMeasurement ?? _body.saveMeasurement)(
        BodyMeasurementEntry(
          id: _newId(),
          authorId: _uid,
          weightKg: weighIn.weightKg,
          date: now,
          source: WeightSource.manual,
          dateCreated: now,
        ),
      );
      await _users.updateUserFields(_uid, [
        UserField.submittedWeightKilograms(weighIn.weightKg),
        UserField.submittedWeightUnitPreference(weighIn.unit),
      ]);
      _track('CheckInView_LogWeight_Success');
      emit(
        state.copyWith(isSaving: false, weighInsSaved: state.weighInsSaved + 1),
      );
      await _advance(emit);
    } on Object catch (error) {
      _fail('CheckInView_LogWeight_Fail', error);
      emit(_alerted(WeeklyCheckInAlert.logWeightFailed));
    }
  }

  Future<void> _onSkipWeighInPressed(
    WeeklyCheckInSkipWeighInPressed event,
    Emitter<WeeklyCheckInState> emit,
  ) async {
    if (_busy) return;
    _stepCompleted(CheckInStep.weighIn, 'skipped');
    await _advance(emit);
  }

  Future<void> _onStartBreakPressed(
    WeeklyCheckInStartBreakPressed event,
    Emitter<WeeklyCheckInState> emit,
  ) async {
    if (_busy) return;
    _stepCompleted(CheckInStep.loggingBreak, 'started');
    await _perform(
      emit,
      'start_logging_break',
      () => _checkIns.startLoggingBreak(_uid, _now()),
    );
  }

  Future<void> _onEndBreakPressed(
    WeeklyCheckInEndBreakPressed event,
    Emitter<WeeklyCheckInState> emit,
  ) async {
    if (_busy) return;
    _stepCompleted(CheckInStep.loggingBreak, 'ended');
    await _perform(
      emit,
      'end_logging_break',
      () => _checkIns.endLoggingBreak(_uid, _now()),
    );
  }

  /// Accepting the proposal is the flow's last act, so it completes the
  /// check-in too.
  Future<void> _onAcceptPressed(
    WeeklyCheckInAcceptPressed event,
    Emitter<WeeklyCheckInState> emit,
  ) async {
    final proposal = state.figures?.proposal;
    if (_busy || proposal == null) return;
    _track('CheckInView_Proposal_Accept', {
      'step': CheckInStep.programUpdate.name,
      ...proposalParameters(proposal),
    });
    await _perform(emit, 'accept_proposal', () => _accept(proposal));
  }

  /// Rebuilds the plan at the proposed target and saves it
  /// (`CoreInteractor.acceptTargetProposal`).
  Future<void> _accept(TargetProposal proposal) async {
    final snapshot = _snapshot;
    final plan = snapshot?.dietPlan;
    final user = snapshot?.user;
    if (plan == null || user == null) return;
    Mesocycle? mesocycle;
    try {
      mesocycle = (await _programs.watchMesocycles(_uid).first)
          .where((m) => m.id == user.submittedActiveMesocycleId)
          .firstOrNull;
    } on Object catch (_) {}
    await _nutrition.saveDietPlan(
      acceptedPlan(
        plan: plan,
        user: user,
        proposal: proposal,
        now: _now(),
        mesocycle: mesocycle,
      ),
    );
    _dismissals.clear(_uid);
  }

  Future<void> _onDonePressed(
    WeeklyCheckInDonePressed event,
    Emitter<WeeklyCheckInState> emit,
  ) async {
    if (_busy) return;
    _stepCompleted(CheckInStep.programUpdate, 'done');
    await _advance(emit);
  }

  WeeklyCheckInState _alerted(WeeklyCheckInAlert alert) =>
      state.copyWith(isSaving: false, alert: alert, alertId: state.alertId + 1);

  /// Runs a step's write and moves on, or stays put with an alert: a failed
  /// save that advanced anyway would leave the user believing the answer
  /// was recorded. [action] names the write for analytics.
  Future<void> _perform(
    Emitter<WeeklyCheckInState> emit,
    String action,
    Future<void> Function() work,
  ) async {
    emit(state.copyWith(isSaving: true));
    _track('CheckInView_SaveAnswer_Start', {'action': action});
    try {
      await work();
      _track('CheckInView_SaveAnswer_Success', {'action': action});
      emit(state.copyWith(isSaving: false));
      await _advance(emit);
    } on Object catch (error) {
      _fail('CheckInView_SaveAnswer_Fail', error, {'action': action});
      emit(_alerted(WeeklyCheckInAlert.saveFailed));
    }
  }

  /// To the next step, or, from the last, records the week as done and
  /// closes. Closing part-way leaves the record alone, so the card stays
  /// for the rest of the week.
  Future<void> _advance(Emitter<WeeklyCheckInState> emit) async {
    final steps = state.flow!.steps;
    if (state.stepIndex < steps.length - 1) {
      final next = state.stepIndex + 1;
      emit(state.copyWith(stepIndex: next));
      _track('CheckInView_Step_Shown', {'step': steps[next].name});
      return;
    }
    emit(state.copyWith(isSaving: true));
    _track('CheckInView_Completed', {'check_in_week_start': state.weekStart});
    try {
      await _checkIns.markCheckInCompleted(_uid, state.weekStart);
      _track('CheckInView_Complete_Success');
      emit(
        state.copyWith(isSaving: false, status: WeeklyCheckInStatus.finished),
      );
    } on Object catch (error) {
      _fail('CheckInView_Complete_Fail', error);
      emit(_alerted(WeeklyCheckInAlert.completeFailed));
    }
  }

  @override
  Future<void> close() {
    _track('CheckInView_Disappear', {
      'step': state.currentStep?.name ?? 'none',
      'check_in_completed': state.status == WeeklyCheckInStatus.finished,
    });
    return super.close();
  }
}
