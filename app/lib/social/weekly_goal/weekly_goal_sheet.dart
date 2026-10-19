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
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
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
        showAdaptiveDialog<void>(
          context: context,
          builder: (context) => AlertDialog.adaptive(
            title: Text(l10n.weeklyGoalSaveFailed),
            content: Text(l10n.socialTryAgain),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.settingsOk),
              ),
            ],
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.l,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.weeklyGoalTitle,
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),
                ),
                if (state.status == WeeklyGoalStatus.saving)
                  const CircularProgressIndicator.adaptive(),
              ],
            ),
            Text(
              selected == null
                  ? l10n.weeklyGoalPrompt
                  : l10n.profileSessionsAWeek(selected),
              style: AppTextStyles.rowTitle,
            ),
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
