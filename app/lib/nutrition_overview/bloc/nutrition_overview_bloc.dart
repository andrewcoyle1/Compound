import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound_maths/compound_maths.dart' show Macros, TargetProposal;
import 'package:equatable/equatable.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:user_repository/user_repository.dart';

part 'nutrition_overview_event.dart';
part 'nutrition_overview_state.dart';

/// The Nutrition Overview (Swift `NutritionOverviewPresenter`): a day's
/// calories, macros and nutrients against its target, with the weekly
/// check-in's card while it is due and the target proposal's card while it
/// is not. Accepting, dismissing and skipping take their card away at once
/// and put it back if the write fails.
class NutritionOverviewBloc
    extends Bloc<NutritionOverviewEvent, NutritionOverviewState> {
  new({
    required this._users,
    required this._nutrition,
    required this._body,
    required this._checkIns,
    required this._programs,
    required this._analytics,
    required this._dismissals,
    required this._uid,
    required String dayKey,
    this._now = DateTime.now,
  }) : super(NutritionOverviewState(dayKey: dayKey)) {
    on<NutritionOverviewStarted>(_onStarted);
    on<NutritionOverviewContributorsToggled>(
      (event, emit) => emit(state.copyWith(showsContributors: event.on)),
    );
    on<NutritionOverviewCheckInStarted>(
      (event, emit) => _track('NutritionOverviewView_CheckIn_Start', {
        'check_in_week_start': state.dueCheckInWeekStart,
      }),
    );
    on<NutritionOverviewCheckInSkipped>(_onCheckInSkipped);
    on<NutritionOverviewProposalAccepted>(_onProposalAccepted);
    on<NutritionOverviewProposalDismissed>(_onProposalDismissed);
  }

  final UserRepository _users;
  final NutritionRepository _nutrition;
  final BodyRepository _body;
  final CheckInRepository _checkIns;
  final ProgramRepository _programs;
  final AnalyticsRepository _analytics;
  final ProposalDismissals _dismissals;
  final String _uid;
  final DateTime Function() _now;

  void _track(
    String name, [
    Map<String, Object?>? parameters,
    LogType type = LogType.analytic,
  ]) => _analytics.trackEvent(
    AnalyticsEvent(name, parameters: parameters, type: type),
  );

  Future<void> _onStarted(
    NutritionOverviewStarted event,
    Emitter<NutritionOverviewState> emit,
  ) {
    _analytics.trackScreenView(
      const AnalyticsEvent('NutritionOverviewView_Appear'),
    );
    return emit.forEach(
      watchExpenditure(
        uid: _uid,
        users: _users,
        nutrition: _nutrition,
        body: _body,
        checkIns: _checkIns,
      ),
      onData: (snapshot) => state.copyWith(
        snapshot: snapshot,
        figures: ExpenditureFigures.of(
          snapshot,
          _now(),
          dismissedKcal: _dismissals.of(_uid),
        ),
      ),
      onError: (error, _) {
        _track('NutritionOverviewView_Load_Fail', {
          'error_description': '$error',
        }, LogType.warning);
        return state.copyWith(failed: true);
      },
    );
  }

  /// Optimistic, and puts the card back if the write does not land: a card
  /// that vanished on a failed write would look like a week dealt with.
  Future<void> _onCheckInSkipped(
    NutritionOverviewCheckInSkipped event,
    Emitter<NutritionOverviewState> emit,
  ) async {
    final weekStart = state.dueCheckInWeekStart;
    if (weekStart == null) return;
    _track('NutritionOverviewView_CheckIn_Skip', {
      'check_in_week_start': weekStart,
    });
    emit(state.copyWith(checkInSkipped: true));
    try {
      await _checkIns.markCheckInSkipped(_uid, weekStart);
      _track('NutritionOverviewView_CheckIn_Skip_Success');
    } on Object catch (error) {
      _track('NutritionOverviewView_CheckIn_Skip_Fail', {
        'error_description': '$error',
      }, LogType.severe);
      emit(
        state.copyWith(
          checkInSkipped: false,
          alert: NutritionOverviewAlert.skipFailed,
          alertId: state.alertId + 1,
        ),
      );
    }
  }

  /// Takes the card away at once and puts it back, with an alert, if the
  /// plan does not save: no card and an unchanged plan would look exactly
  /// like success.
  Future<void> _onProposalAccepted(
    NutritionOverviewProposalAccepted event,
    Emitter<NutritionOverviewState> emit,
  ) async {
    final proposal = state.proposal;
    final snapshot = state.snapshot;
    final plan = snapshot?.dietPlan;
    final user = snapshot?.user;
    if (state.isApplyingProposal || proposal == null) return;
    _track(
      'NutritionOverviewView_Proposal_Accept',
      proposalParameters(proposal),
    );
    emit(state.copyWith(isApplyingProposal: true, proposalHidden: true));
    try {
      if (plan != null && user != null) {
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
      _track('NutritionOverviewView_Proposal_Accept_Success');
      emit(state.copyWith(isApplyingProposal: false));
    } on Object catch (error) {
      _track('NutritionOverviewView_Proposal_Accept_Fail', {
        'error': '$error',
      }, LogType.severe);
      emit(
        state.copyWith(
          isApplyingProposal: false,
          proposalHidden: false,
          alert: NutritionOverviewAlert.acceptFailed,
          alertId: state.alertId + 1,
        ),
      );
    }
  }

  /// Remembers the figure waved away, so the same card does not return.
  void _onProposalDismissed(
    NutritionOverviewProposalDismissed event,
    Emitter<NutritionOverviewState> emit,
  ) {
    final proposal = state.proposal;
    if (proposal == null) return;
    _track(
      'NutritionOverviewView_Proposal_Dismiss',
      proposalParameters(proposal),
    );
    _dismissals.dismiss(_uid, proposal.proposedTargetKcal);
    emit(state.copyWith(proposalHidden: true));
  }

  @override
  Future<void> close() {
    _track('NutritionOverviewView_Disappear');
    return super.close();
  }
}
