import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/social/weekly_goal/weekly_goal_cubit.dart';
import 'package:compound_maths/compound_maths.dart'
    show maxWeeklySessionGoal, minWeeklySessionGoal;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';

/// Opens the weekly goal sheet for [viewer] (Swift `WeeklyGoalView`, a
/// half sheet), from the strip's Set goal and the own profile.
Future<void> showWeeklyGoalSheet(BuildContext context, UserModel viewer) =>
    showAppSheet<void>(
      context: context,
      size: AppSheetSize.compact,
      builder: (_) => BlocProvider(
        create: (_) => WeeklyGoalCubit(
          users: context.read<UserRepository>(),
          analytics: context.read<AnalyticsRepository>(),
          uid: viewer.userId,
          savedGoal: viewer.weeklySessionGoal,
        )..appeared(),
        child: const WeeklyGoalView(),
      ),
    );

class WeeklyGoalView extends StatefulWidget {
  const new({super.key});

  @override
  State<WeeklyGoalView> createState() => _WeeklyGoalViewState();
}

class _WeeklyGoalViewState extends State<WeeklyGoalView> {
  late final WeeklyGoalCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<WeeklyGoalCubit>();
  }

  @override
  void dispose() {
    _cubit.disappeared();
    super.dispose();
  }

  void _onStatus(BuildContext context, WeeklyGoalState state) {
    final l10n = context.l10n;
    switch (state.status) {
      case WeeklyGoalStatus.saved:
        unawaited(HapticFeedback.mediumImpact());
        Navigator.of(context).pop();
      case WeeklyGoalStatus.failed:
        unawaited(HapticFeedback.heavyImpact());
        unawaited(
          showAppDialog<void>(
            context: context,
            title: l10n.weeklyGoalSaveFailed,
            message: l10n.socialTryAgain,
            actions: [AppDialogAction(label: l10n.settingsOk)],
          ),
        );
      case WeeklyGoalStatus.editing || WeeklyGoalStatus.saving:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<WeeklyGoalCubit>().state;
    final selected = state.selected;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return BlocListener<WeeklyGoalCubit, WeeklyGoalState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.failureId != current.failureId,
      listener: _onStatus,
      child: AppScaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: AppToolbarButton.close(semanticLabel: l10n.socialClose),
          title: Text(l10n.weeklyGoalTitle),
          actions: [
            if (state.status == WeeklyGoalStatus.saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            Text(
              selected == null
                  ? l10n.weeklyGoalPrompt
                  : l10n.profileSessionsAWeek(selected),
              style: AppTextStyles.rowTitle,
            ),
            const SizedBox(height: AppSpacing.l),
            AppSegmentedControl<int>(
              segments: [
                for (
                  var goal = minWeeklySessionGoal;
                  goal <= maxWeeklySessionGoal;
                  goal++
                )
                  AppSegment(value: goal, label: '$goal'),
              ],
              selected: selected,
              onChanged: state.status == WeeklyGoalStatus.saving
                  ? null
                  : (goal) => unawaited(_cubit.goalSelected(goal)),
            ),
            const SizedBox(height: AppSpacing.l),
            Text(
              l10n.weeklyGoalFooter,
              style: AppTextStyles.label.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}
