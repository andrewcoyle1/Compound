import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/view/check_in_page.dart'
    show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/timeline_actions/timeline_day_cubit.dart';
import 'package:compound/programs/view/program_widgets.dart'
    show confirmDestructive;
import 'package:compound/settings/nutrition/cubit/food_log_settings_cubit.dart';
import 'package:compound/settings/nutrition/cubit/settings_document_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// Timeline Actions for [day] (Swift `TimelineActionsView`, a compact
/// sheet): Copy Day, Clear Day, and the Hide Food Details and Hide Empty
/// Hours toggles.
Future<void> showTimelineActions(BuildContext context, DateTime day) {
  final app = context.read<AppBloc>().state;
  final uid = app is AppAuthenticated ? app.user.uid : null;
  final nutrition = context.read<NutritionRepository>();
  final analytics = context.read<AnalyticsRepository>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => MultiBlocProvider(
      providers: [
        if (uid != null)
          BlocProvider(
            create: (_) => FoodLogSettingsCubit(
              nutritionRepository: nutrition,
              analytics: analytics,
              uid: uid,
              screen: 'TimelineActionsView',
            ),
          ),
        BlocProvider(
          create: (_) => TimelineDayCubit(
            uid: uid,
            day: day,
            nutrition: nutrition,
            analytics: analytics,
          ),
        ),
      ],
      child: TimelineActionsView(signedIn: uid != null),
    ),
  );
}

class TimelineActionsView extends StatelessWidget {
  const new({required this.signedIn, super.key});

  /// Whether there are settings to toggle.
  final bool signedIn;

  Future<void> _copy(BuildContext context) async {
    final cubit = context.read<TimelineDayCubit>();
    final destination = await showDatePicker(
      context: context,
      initialDate: cubit.defaultCopyDestination,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: context.l10n.timelineCopyTo,
      confirmText: context.l10n.timelineCopy,
    );
    if (destination != null) await cubit.copyDay(destination);
  }

  Future<void> _alert(BuildContext context, TimelineDayState state) async {
    final l10n = context.l10n;
    final cubit = context.read<TimelineDayCubit>();
    switch (state.alert) {
      case TimelineDayAlert.nothingToCopy:
        await showFailureAlert(
          context,
          l10n.timelineNothingToCopy,
          l10n.timelineNoMeals,
        );
      case TimelineDayAlert.nothingToClear:
        await showFailureAlert(
          context,
          l10n.timelineNothingToClear,
          l10n.timelineNoMeals,
        );
      case TimelineDayAlert.confirmClear:
        // Destructive and not undoable, so it is confirmed first.
        final confirmed = await confirmDestructive(
          context,
          title: l10n.timelineClearTitle,
          message: l10n.timelineClearMessage(state.meals.length),
          confirmLabel: l10n.timelineClearDay,
        );
        if (confirmed) await cubit.clearDay();
      case TimelineDayAlert.copyFailed:
        unawaited(HapticFeedback.errorNotification());
        await showFailureAlert(
          context,
          l10n.timelineCopyFailed,
          l10n.timelineTryAgain,
        );
      case TimelineDayAlert.clearFailed:
        unawaited(HapticFeedback.errorNotification());
        await showFailureAlert(
          context,
          l10n.timelineClearFailed,
          l10n.timelineTryAgain,
        );
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final day = context.watch<TimelineDayCubit>().state;
    final settings = signedIn
        ? context.watch<FoodLogSettingsCubit>().state.settings
        : null;
    return MultiBlocListener(
      listeners: [
        BlocListener<TimelineDayCubit, TimelineDayState>(
          listenWhen: (previous, current) =>
              current.alertCount != previous.alertCount,
          listener: (context, state) => unawaited(_alert(context, state)),
        ),
        BlocListener<TimelineDayCubit, TimelineDayState>(
          listenWhen: (previous, current) => !previous.done && current.done,
          listener: (context, _) {
            unawaited(HapticFeedback.successNotification());
            Navigator.of(context).pop();
          },
        ),
        if (signedIn)
          BlocListener<
            FoodLogSettingsCubit,
            SettingsDocumentState<FoodLogSettings>
          >(
            listenWhen: (previous, current) =>
                current.saveFailures > previous.saveFailures,
            listener: (context, _) {
              unawaited(HapticFeedback.errorNotification());
              unawaited(
                showFailureAlert(
                  context,
                  l10n.timelineSaveFailed,
                  l10n.timelineTryAgain,
                ),
              );
            },
          ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.m,
          children: [
            Text(
              l10n.timelineActionsTitle,
              style: AppTextStyles.sectionTitle,
              textAlign: TextAlign.center,
            ),
            AppSection(
              children: [
                AppListRowButton(
                  title: l10n.timelineCopyDay,
                  icon: AppSymbols.duplicate,
                  accessory: null,
                  onPressed: day.isWorking
                      ? null
                      : () => unawaited(_copy(context)),
                ),
                AppListRowButton(
                  title: l10n.timelineClearDay,
                  icon: AppSymbols.delete,
                  tint: context.appColors.danger,
                  accessory: null,
                  onPressed: day.isWorking
                      ? null
                      : context.read<TimelineDayCubit>().clearDayPressed,
                ),
                if (settings != null) ...[
                  AppListRowToggle(
                    title: l10n.timelineHideFoodDetails,
                    value: settings.hideFoodDetails,
                    onChanged: (value) => unawaited(
                      context.read<FoodLogSettingsCubit>().set(
                        FoodLogSettingsKeys.hideFoodDetails,
                        value,
                      ),
                    ),
                  ),
                  AppListRowToggle(
                    title: l10n.timelineHideEmptyHours,
                    value: settings.hideEmptyHours,
                    onChanged: (value) => unawaited(
                      context.read<FoodLogSettingsCubit>().set(
                        FoodLogSettingsKeys.hideEmptyHours,
                        value,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
