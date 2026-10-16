import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/report/report_cubit.dart';
import 'package:flutter/services.dart';
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
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final sending = await showModalBottomSheet<Future<bool>>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: ReportView(type: content.type),
    ),
  );
  final sent = sending == null ? null : await sending;
  await cubit.close();
  if (sent == null) return;
  if (sent) {
    unawaited(HapticFeedback.mediumImpact());
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(reportSentMessage(l10n, content.type))),
      );
  } else if (context.mounted) {
    unawaited(HapticFeedback.heavyImpact());
    await showAdaptiveDialog<void>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(l10n.reportFailed),
        content: Text(l10n.socialTryAgain),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.settingsOk),
          ),
        ],
      ),
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
    final secondary = AppTextStyles.label.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.s,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(AppSymbols.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final sending = cubit.sendPressed();
                    if (sending != null) Navigator.of(context).pop(sending);
                  },
                  child: Text(l10n.reportSend),
                ),
              ],
            ),
            Text(prompt, style: secondary),
            for (final reason in ReportReason.values)
              AppSelectableRow(
                title: reportReasonName(l10n, reason),
                selected: state.reason == reason,
                onPressed: () => cubit.reasonSelected(reason),
              ),
            const SizedBox(height: AppSpacing.s),
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
            if (problem != null)
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
        ),
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
