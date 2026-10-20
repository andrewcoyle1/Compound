import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:compound/nutrition_overview/nutrition_overview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const uid = StagingData.uid;

  late StagingData data;
  late AnalyticsRecorder analytics;
  late ProposalDismissals dismissals;

  setUp(() {
    data = StagingData();
    analytics = AnalyticsRecorder();
    dismissals = ProposalDismissals();
  });

  NutritionOverviewBloc build({
    NutritionRepository? nutrition,
    CheckInRepository? checkIns,
  }) => NutritionOverviewBloc(
    users: data.users,
    nutrition: nutrition ?? data.nutrition,
    body: data.body,
    checkIns: checkIns ?? data.checkIns,
    programs: data.programs,
    analytics: analytics,
    dismissals: dismissals,
    uid: uid,
    dayKey: '2026-10-15',
    now: () => data.now,
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group(NutritionOverviewBloc, () {
    test("reads the day and the week's check-in", () async {
      final bloc = build();
      expect(bloc.state.isLoaded, isFalse);
      bloc.add(const NutritionOverviewStarted());
      await settle();
      final state = bloc.state;
      expect(state.isLoaded, isTrue);
      expect(state.meals, isNotEmpty);
      expect(state.totals.calories, greaterThan(0));
      expect(state.target, isNotNull);
      expect(state.dueCheckInWeekStart, DateTime(2026, 10, 12));
      // The check-in's card takes the proposal's place.
      expect(state.figures!.proposal, isNotNull);
      expect(state.proposal, isNull);
      expect(analytics.names, ['NutritionOverviewView_Appear']);

      bloc
        ..add(const NutritionOverviewContributorsToggled(on: true))
        ..add(const NutritionOverviewCheckInStarted());
      await settle();
      expect(bloc.state.showsContributors, isTrue);
      expect(analytics.parameters('NutritionOverviewView_CheckIn_Start'), {
        'check_in_week_start': DateTime(2026, 10, 12),
      });
      await bloc.close();
      expect(analytics.names.last, 'NutritionOverviewView_Disappear');
    });

    test('skips the check-in, then offers the proposal', () async {
      final bloc = build()..add(const NutritionOverviewStarted());
      await settle();
      bloc.add(const NutritionOverviewCheckInSkipped());
      await settle();
      expect(bloc.state.dueCheckInWeekStart, isNull);
      expect(bloc.state.proposal, isNotNull);
      final record = await data.checkIns.watchCheckInRecord(uid).first;
      expect(record!.lastSkippedWeekStart, DateTime(2026, 10, 12));
      expect(
        analytics.names,
        containsAllInOrder([
          'NutritionOverviewView_CheckIn_Skip',
          'NutritionOverviewView_CheckIn_Skip_Success',
        ]),
      );
      // Nothing left to skip.
      bloc.add(const NutritionOverviewCheckInSkipped());
      await settle();
      expect(
        analytics.names.where((n) => n == 'NutritionOverviewView_CheckIn_Skip'),
        hasLength(1),
      );
    });

    test('accepts the proposal into the plan', () async {
      data = StagingData(
        records: [
          CheckInRecord(
            authorId: uid,
            lastCompletedWeekStart: DateTime(2026, 10, 12),
          ),
        ],
      );
      dismissals.dismiss(uid, 1);
      final bloc = build()..add(const NutritionOverviewStarted());
      await settle();
      final proposal = bloc.state.proposal!;
      bloc.add(const NutritionOverviewProposalAccepted());
      await settle();
      expect(bloc.state.proposal, isNull);
      expect(bloc.state.isApplyingProposal, isFalse);
      final plan = (await data.nutrition.watchDietPlan(uid).first)!;
      final mean =
          plan.days.map((day) => day.calories).reduce((a, b) => a + b) / 7;
      expect(mean, closeTo(proposal.proposedTargetKcal, 1));
      expect(dismissals.of(uid), isNull);
      expect(
        analytics.names,
        containsAllInOrder([
          'NutritionOverviewView_Proposal_Accept',
          'NutritionOverviewView_Proposal_Accept_Success',
        ]),
      );
      // Nothing left to accept.
      bloc.add(const NutritionOverviewProposalAccepted());
      await settle();
    });

    test('dismisses the proposal, and remembers it', () async {
      data = StagingData(
        records: [
          CheckInRecord(
            authorId: uid,
            lastCompletedWeekStart: DateTime(2026, 10, 12),
          ),
        ],
      );
      final bloc = build()..add(const NutritionOverviewStarted());
      await settle();
      final proposal = bloc.state.proposal!;
      bloc.add(const NutritionOverviewProposalDismissed());
      await settle();
      expect(bloc.state.proposal, isNull);
      expect(dismissals.of(uid), proposal.proposedTargetKcal);
      expect(
        analytics.parameters('NutritionOverviewView_Proposal_Dismiss'),
        proposalParameters(proposal),
      );
      bloc.add(const NutritionOverviewProposalDismissed());
      await settle();
    });

    test('puts the cards back when their writes fail', () async {
      final failing = _RefusingCheckIns(data.checkIns);
      final bloc = build(
        nutrition: _RefusingNutrition(data.nutrition),
        checkIns: failing,
      )..add(const NutritionOverviewStarted());
      await settle();
      bloc.add(const NutritionOverviewCheckInSkipped());
      await settle();
      expect(bloc.state.dueCheckInWeekStart, isNotNull);
      expect(bloc.state.alert, NutritionOverviewAlert.skipFailed);

      // Done this week elsewhere: the proposal shows.
      await data.checkIns.markCheckInCompleted(uid, DateTime(2026, 10, 12));
      await settle();
      bloc.add(const NutritionOverviewProposalAccepted());
      await settle();
      expect(bloc.state.proposal, isNotNull);
      expect(bloc.state.alert, NutritionOverviewAlert.acceptFailed);
      expect(bloc.state.alertId, 2);
      expect(
        analytics.parameters('NutritionOverviewView_Proposal_Accept_Fail'),
        {'error': 'Exception: refused'},
      );
    });

    test('says when the day cannot be read', () async {
      final bloc = build(nutrition: _ThrowingNutrition())
        ..add(const NutritionOverviewStarted());
      await settle();
      expect(bloc.state.failed, isTrue);
      expect(analytics.names, contains('NutritionOverviewView_Load_Fail'));
    });
  });
}

class _RefusingCheckIns implements CheckInRepository {
  new(this._inner);

  final CheckInRepository _inner;

  @override
  Stream<NutritionStrategySettings> watchStrategySettings(String uid) =>
      _inner.watchStrategySettings(uid);

  @override
  Stream<List<NutritionDayAnnotation>> watchDayAnnotations(String uid) =>
      _inner.watchDayAnnotations(uid);

  @override
  Stream<LoggingBreak?> watchLoggingBreak(String uid) =>
      _inner.watchLoggingBreak(uid);

  @override
  Stream<CheckInRecord?> watchCheckInRecord(String uid) =>
      _inner.watchCheckInRecord(uid);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<void>.error(Exception('refused'));
}

class _RefusingNutrition extends InMemoryNutritionRepository {
  new(this._inner);

  final InMemoryNutritionRepository _inner;

  @override
  Stream<List<MealLogModel>> watchMeals(
    String uid, {
    bool includeHiddenHealthImports = false,
  }) => _inner.watchMeals(uid);

  @override
  Stream<DietPlan?> watchDietPlan(String uid) => _inner.watchDietPlan(uid);

  @override
  Future<void> saveDietPlan(DietPlan plan) =>
      Future.error(Exception('refused'));
}

class _ThrowingNutrition extends InMemoryNutritionRepository {
  @override
  Stream<List<MealLogModel>> watchMeals(
    String uid, {
    bool includeHiddenHealthImports = false,
  }) => Stream.error(Exception('offline'));
}
