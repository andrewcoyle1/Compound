import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/general/cubit/notification_settings_cubit.dart';
import 'package:compound/settings/general/view/on_dispose.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:user_repository/user_repository.dart';

/// Which pushes and reminders arrive (Swift `NotificationSettingsView`).
/// Each switch saves as it changes; above them, the permission prompt, and
/// they stay off until notifications are allowed.
class NotificationSettingsPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'notifications';
  static const name = 'settingsNotifications';

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) {
        final cubit = NotificationSettingsCubit(
          users: context.read<UserRepository>(),
          notifications: context.read<NotificationsRepository>(),
          analytics: context.read<AnalyticsRepository>(),
          uid: state.user.uid,
        )..appeared();
        unawaited(cubit.checkPermission());
        return cubit;
      },
      child: const NotificationSettingsView(),
    );
  }
}

class NotificationSettingsView extends StatefulWidget {
  const new({super.key});

  @override
  State<NotificationSettingsView> createState() =>
      _NotificationSettingsViewState();
}

class _NotificationSettingsViewState extends State<NotificationSettingsView> {
  /// The system settings are where a refusal is undone, so the permission is
  /// read again on each return to the app.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(
        context.read<NotificationSettingsCubit>().checkPermission(),
      ),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<NotificationSettingsCubit>();
    final state = context.watch<NotificationSettingsCubit>().state;
    final enabled = state.canChangeSwitches;
    String hour(int hour) => AppFormat.hour(
      hour,
      use24HourFormat: context.use24HourFormat,
      locale: context.dateLocale,
    );
    return OnDispose(
      onDispose: cubit.disappeared,
      child: BlocListener<NotificationSettingsCubit, NotificationSettingsState>(
        listenWhen: (previous, current) =>
            current.failureId != previous.failureId,
        listener: (context, state) =>
            showAppSnackBar(context, switch (state.failure!) {
              NotificationSettingsFailure.save =>
                l10n.notificationSettingsSaveFailed,
              NotificationSettingsFailure.checkPermission =>
                l10n.notificationSettingsCheckFailed,
              NotificationSettingsFailure.requestPermission =>
                l10n.notificationSettingsEnableFailed,
            }, style: AppSnackBarStyle.error),
        child: AppScaffold(
          appBar: AppBar(title: Text(l10n.settingsNotificationSettings)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                ...switch (state.permissionPrompt) {
                  PermissionPrompt.askFirst => [
                    AppSection(
                      children: [
                        AppInlineMessage(
                          kind: AppInlineMessageKind.info,
                          kindLabel: l10n.infoLabel,
                          text: l10n.notificationSettingsAskFirst,
                        ),
                        AppListRowButton(
                          title: l10n.notificationSettingsTurnOn,
                          icon: AppSymbols.notifications,
                          onPressed: cubit.requestPermissionPressed,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  PermissionPrompt.denied => [
                    AppSection(
                      children: [
                        AppInlineMessage(
                          kind: AppInlineMessageKind.warning,
                          kindLabel: l10n.warningLabel,
                          text: l10n.notificationSettingsDenied,
                        ),
                        AppListRowButton(
                          title: l10n.notificationSettingsOpenSettings,
                          icon: AppSymbols.settings,
                          onPressed: cubit.openSettingsPressed,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  null => const <Widget>[],
                },
                AppSection(
                  header: l10n.notificationSettingsSocialHeader,
                  footer: l10n.notificationSettingsSocialFooter,
                  children: [
                    for (final push in SocialPush.values)
                      AppListRowToggle(
                        title: _title(l10n, push),
                        value: state.isSocialPushEnabled(push),
                        onChanged: !enabled
                            ? null
                            : (isEnabled) => cubit.socialPushChanged(
                                push,
                                isEnabled: isEnabled,
                              ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                AppSection(
                  header: l10n.notificationSettingsRemindersHeader,
                  footer: l10n.notificationSettingsRemindersFooter,
                  children: [
                    AppListRowToggle(
                      title: l10n.notificationSettingsStreakReminder,
                      value: state.isStreakReminderEnabled,
                      onChanged: !enabled
                          ? null
                          : (isEnabled) => cubit.streakReminderChanged(
                              isEnabled: isEnabled,
                            ),
                    ),
                    if (state.isStreakReminderEnabled)
                      AppListRowButton(
                        title: l10n.notificationSettingsRemindAt,
                        accessory: AppListRowMenu(hour(state.reminderHour)),
                        onPressed: !enabled
                            ? null
                            : () => _chooseHour(
                                context,
                                selected: state.reminderHour,
                                label: hour,
                              ),
                      ),
                    AppListRowToggle(
                      title: l10n.notificationSettingsWeeklyDigest,
                      value: state.isWeeklyDigestEnabled,
                      onChanged: !enabled
                          ? null
                          : (isEnabled) =>
                                cubit.weeklyDigestChanged(isEnabled: isEnabled),
                    ),
                    AppListRowToggle(
                      title: l10n.notificationSettingsWorkoutReminders,
                      value: state.isComeBackRemindersEnabled,
                      onChanged: !enabled
                          ? null
                          : (isEnabled) => cubit.comeBackRemindersChanged(
                              isEnabled: isEnabled,
                            ),
                    ),
                    AppListRowToggle(
                      title: l10n.notificationSettingsMealReminders,
                      value: state.isMealRemindersEnabled,
                      onChanged: !enabled
                          ? null
                          : (isEnabled) => cubit.mealRemindersChanged(
                              isEnabled: isEnabled,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The 24 hours, as Swift's picker offers them.
  static Future<void> _chooseHour(
    BuildContext context, {
    required int selected,
    required String Function(int) label,
  }) async {
    final cubit = context.read<NotificationSettingsCubit>();
    final hour = await showAppSheet<int>(
      context: context,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppSection(
            header: context.l10n.notificationSettingsRemindAt,
            children: [
              for (var hour = 0; hour < 24; hour++)
                AppSelectableRow(
                  title: label(hour),
                  selected: hour == selected,
                  onPressed: () => Navigator.of(context).pop(hour),
                ),
            ],
          ),
        ],
      ),
    );
    if (hour != null && hour != selected) {
      await cubit.reminderHourChanged(hour);
    }
  }

  static String _title(AppLocalizations l10n, SocialPush push) =>
      switch (push) {
        SocialPush.likes => l10n.notificationSettingsLikes,
        SocialPush.comments => l10n.notificationSettingsComments,
        SocialPush.mentions => l10n.notificationSettingsMentions,
        SocialPush.follows => l10n.notificationSettingsFollows,
        SocialPush.nudges => l10n.notificationSettingsNudges,
        SocialPush.shares => l10n.notificationSettingsShares,
        SocialPush.challenges => l10n.notificationSettingsChallenges,
      };
}
