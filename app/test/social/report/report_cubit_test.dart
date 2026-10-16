import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/social/report/report_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_repository/social_repository.dart';

import '../../helpers/helpers.dart';

class _MockSocial extends Mock implements SocialRepository;

// Ported from Swift's ReportReasonFlowTests, ReportManagerTests and
// SocialSafetyTests' ReportFlowTests.
void main() {
  const comment = ReportedContent(
    type: ReportContentType.comment,
    id: 'c1',
    authorId: 'friend',
  );
  late _MockSocial social;
  late AnalyticsRecorder analytics;
  late List<String> reports;

  setUpAll(() {
    registerFallbackValue(ReportContentType.comment);
    registerFallbackValue(ReportReason.spam);
  });

  setUp(() {
    social = _MockSocial();
    analytics = AnalyticsRecorder();
    reports = [];
    when(
      () => social.report(
        reporterId: any(named: 'reporterId'),
        targetType: any(named: 'targetType'),
        targetId: any(named: 'targetId'),
        reason: any(named: 'reason'),
        targetAuthorId: any(named: 'targetAuthorId'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((call) async {
      String? arg(Symbol name) => switch (call.namedArguments[name]) {
        final ReportContentType type => type.value,
        final ReportReason reason => reason.value,
        final Object? other => other as String?,
      };
      reports.add(
        [
          arg(#reporterId),
          arg(#targetType),
          arg(#targetId),
          arg(#targetAuthorId),
          arg(#reason),
          arg(#note),
        ].map((part) => part ?? '').join('|'),
      );
    });
  });

  ReportCubit build({
    ReportedContent content = comment,
    String? reporterId = 'me',
  }) => ReportCubit(
    social: social,
    analytics: analytics,
    content: content,
    reporterId: reporterId,
  );

  group('problem', () {
    test('needs a reason, a note for Other, and a short note', () {
      expect(ReportCubit.problem(null, ''), ReportProblem.noReason);
      expect(ReportCubit.problem(ReportReason.spam, ''), isNull);
      expect(
        ReportCubit.problem(ReportReason.other, '   \n'),
        ReportProblem.noNote,
      );
      expect(ReportCubit.problem(ReportReason.other, 'Fake workout'), isNull);
      expect(
        ReportCubit.problem(ReportReason.harassment, 'a' * 501),
        ReportProblem.noteTooLong,
      );
      expect(ReportCubit.problem(ReportReason.harassment, 'a' * 500), isNull);
    });

    test('counts the note as the rules do, in UTF-16 code units', () {
      expect(ReportCubit.problem(ReportReason.spam, '💪' * 250), isNull);
      expect(
        ReportCubit.problem(ReportReason.spam, '💪' * 251),
        ReportProblem.noteTooLong,
      );
    });
  });

  group(ReportCubit, () {
    test('Other without a note is not sent and asks again', () async {
      final cubit = build()..reasonSelected(ReportReason.other);

      expect(cubit.sendPressed(), isNull);
      expect(cubit.state.problem, ReportProblem.noNote);
      expect(cubit.state.reason, ReportReason.other);
      expect(reports, isEmpty);

      cubit.noteChanged("  Posting someone else's workout  ");
      expect(await cubit.sendPressed(), isTrue);
      expect(reports, [
        "me|comment|c1|friend|other|Posting someone else's workout",
      ]);
      await cubit.close();
    });

    test('a reason without a note sends no note', () async {
      final cubit = build()
        ..reasonSelected(ReportReason.inappropriate)
        ..noteChanged('   ');

      expect(await cubit.sendPressed(), isTrue);
      expect(reports, ['me|comment|c1|friend|inappropriate|']);
      await cubit.close();
    });

    test('sending without a reason stays, and a reason clears it', () async {
      final cubit = build();

      expect(cubit.sendPressed(), isNull);
      expect(cubit.state.problem, ReportProblem.noReason);
      cubit.reasonSelected(ReportReason.spam);
      expect(cubit.state.problem, isNull);
      await cubit.close();
    });

    test('a note too long stays in the sheet', () async {
      final cubit = build()
        ..reasonSelected(ReportReason.spam)
        ..noteChanged('a' * 501);

      expect(cubit.sendPressed(), isNull);
      expect(cubit.state.problem, ReportProblem.noteTooLong);
      expect(cubit.state.note, 'a' * 501);
      await cubit.close();
    });

    test('a workout report names the session and its author', () async {
      final cubit = build(
        content: const ReportedContent(
          type: ReportContentType.session,
          id: 'session-x',
          authorId: 'friend',
        ),
      )..reasonSelected(ReportReason.spam);

      expect(await cubit.sendPressed(), isTrue);
      expect(reports, ['me|session|session-x|friend|spam|']);
      expect(analytics.names, [
        'ReportFlow_Report_Start',
        'Report_Submit_Start',
        'Report_Submit_Success',
        'ReportFlow_Report_Success',
      ]);
      expect(analytics.parameters('ReportFlow_Report_Success'), {
        'content_type': 'session',
        'reason': 'spam',
      });
      expect(analytics.parameters('Report_Submit_Start'), {
        'content_type': 'session',
        'content_id': 'session-x',
        'reason': 'spam',
      });
      expect(analytics.parameters('Report_Submit_Success'), {
        'content_type': 'session',
        'content_id': 'session-x',
      });
      await cubit.close();
    });

    test('a report with no known author keeps it absent', () async {
      final cubit =
          build(
              content: const ReportedContent(
                type: ReportContentType.comment,
                id: 'c1',
              ),
            )
            ..reasonSelected(ReportReason.other)
            ..noteChanged('x');

      expect(await cubit.sendPressed(), isTrue);
      expect(reports, ['me|comment|c1||other|x']);
      await cubit.close();
    });

    test('without a signed-in reporter it sends nothing and fails', () async {
      final cubit = build(reporterId: null)..reasonSelected(ReportReason.spam);

      expect(await cubit.sendPressed(), isFalse);
      expect(reports, isEmpty);
      expect(analytics.names, [
        'ReportFlow_Report_Start',
        'ReportFlow_Report_Fail',
      ]);
      await cubit.close();
    });

    test('a failed submission tracks the start but not the success', () async {
      when(
        () => social.report(
          reporterId: any(named: 'reporterId'),
          targetType: any(named: 'targetType'),
          targetId: any(named: 'targetId'),
          reason: any(named: 'reason'),
          targetAuthorId: any(named: 'targetAuthorId'),
          note: any(named: 'note'),
        ),
      ).thenThrow(StateError('offline'));
      final cubit = build()..reasonSelected(ReportReason.spam);

      expect(await cubit.sendPressed(), isFalse);
      expect(analytics.names, [
        'ReportFlow_Report_Start',
        'Report_Submit_Start',
        'ReportFlow_Report_Fail',
      ]);
      expect(analytics.events.last.type, LogType.severe);
      await cubit.close();
    });
  });
}
