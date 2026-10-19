import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/report/report_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_repository/social_repository.dart';

/// Opens the report sheet for [content] (Swift `ReportSheetView`, a half
/// sheet), as the signed-in reader. Once sent it says whether it went: a
/// snack bar on success, an alert on failure.
Future<void> showReportSheet(
  BuildContext context,
  ReportedContent content,
) async {
  final cubit = ReportCubit(
    social: context.read<SocialRepository>(),
    analytics: context.read<AnalyticsRepository>(),
    content: content,
    reporterId: context.read<CircleBloc>().state.viewer?.userId,
  );
  final snackBars = AppSnackBarScope.of(context);
  final l10n = context.l10n;
  final sending = await showAppSheet<Future<bool>>(
    context: context,
    // Full height: the reasons, a note and the keyboard.
    size: AppSheetSize.full,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: ReportView(type: content.type),
    ),
  );
  final sent = sending == null ? null : await sending;
  await cubit.close();
  if (sent == null) return;
  if (sent) {
    unawaited(AppHaptics.medium());
    snackBars.show(
      reportSentMessage(l10n, content.type),
      style: AppSnackBarStyle.success,
    );
  } else if (context.mounted) {
    unawaited(AppHaptics.heavy());
    await showAppDialog<void>(
      context: context,
      title: l10n.reportFailed,
      message: l10n.socialTryAgain,
      actions: [AppDialogAction(label: l10n.settingsOk)],
    );
  }
}

/// "Report sent. Thanks — we will take a look at this …".
String reportSentMessage(AppLocalizations l10n, ReportContentType type) =>
    switch (type) {
      ReportContentType.comment => l10n.reportSentComment,
      ReportContentType.session => l10n.reportSentWorkout,
      ReportContentType.user => l10n.reportSentProfile,
    };

/// The reasons, the note, Close and Send. The cubit holds the state.
class ReportView extends StatelessWidget {
  const new({required this.type, super.key});

  final ReportContentType type;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ReportCubit>();
    final state = context.watch<ReportCubit>().state;
    final (title, prompt) = switch (type) {
      ReportContentType.comment => (
        l10n.reportCommentTitle,
        l10n.reportCommentPrompt,
      ),
      ReportContentType.session => (
        l10n.reportWorkoutTitle,
        l10n.reportWorkoutPrompt,
      ),
      ReportContentType.user => (
        l10n.reportProfileTitle,
        l10n.reportProfilePrompt,
      ),
    };
    final problem = state.problem;
    return AppScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppToolbarButton.close(
          semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
        ),
        title: Text(title),
        actions: [
          AppToolbarButton.confirm(
            semanticLabel: l10n.reportSend,
            onPressed: () {
              final sending = cubit.sendPressed();
              if (sending != null) Navigator.of(context).pop(sending);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppSection(
            header: prompt,
            children: [
              for (final reason in ReportReason.values)
                AppSelectableRow(
                  title: reportReasonName(l10n, reason),
                  selected: state.reason == reason,
                  onPressed: () => cubit.reasonSelected(reason),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            onChanged: cubit.noteChanged,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: l10n.reportNote,
              helperText: state.reason == ReportReason.other
                  ? l10n.reportNoteRequired
                  : l10n.reportNoteOptional,
              helperMaxLines: 2,
            ),
          ),
          if (problem != null) ...[
            const SizedBox(height: AppSpacing.s),
            AppInlineMessage(
              kind: AppInlineMessageKind.error,
              kindLabel: l10n.errorLabel,
              text: switch (problem) {
                ReportProblem.noReason => l10n.reportNoReason,
                ReportProblem.noNote => l10n.reportNoNote,
                ReportProblem.noteTooLong => l10n.reportNoteTooLong(
                  ReportCubit.noteLimit,
                ),
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// A reason's name (`ReportReason.displayName`).
String reportReasonName(AppLocalizations l10n, ReportReason reason) =>
    switch (reason) {
      ReportReason.spam => l10n.reportReasonSpam,
      ReportReason.harassment => l10n.reportReasonHarassment,
      ReportReason.inappropriate => l10n.reportReasonInappropriate,
      ReportReason.other => l10n.reportReasonOther,
    };
