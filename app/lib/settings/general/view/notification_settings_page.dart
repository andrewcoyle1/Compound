import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/general/cubit/notification_settings_cubit.dart';
import 'package:compound/settings/general/view/on_dispose.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:user_repository/user_repository.dart';

/// Which pushes and reminders arrive (Swift `NotificationSettingsView`).
/// Each switch saves as it changes. The permission prompt waits for the
/// push wiring.
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
      create: (context) => NotificationSettingsCubit(
        users: context.read<UserRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        uid: state.user.uid,
      )..appeared(),
      child: const NotificationSettingsView(),
    );
  }
}

class NotificationSettingsView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<NotificationSettingsCubit>();
    final state = context.watch<NotificationSettingsCubit>().state;
    String hour(int hour) =>
        DateFormat.j(Localizations.localeOf(context).toLanguageTag())
            .format(DateTime(2000, 1, 1, hour));
    return OnDispose(
      onDispose: cubit.disappeared,
      child: BlocListener<NotificationSettingsCubit, NotificationSettingsState>(
        listenWhen: (_, state) => state.saveFailed,
        listener: (context, _) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.notificationSettingsSaveFailed)),
          ),
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.settingsNotificationSettings)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                AppSection(
                  header: l10n.notificationSettingsSocialHeader,
                  footer: l10n.notificationSettingsSocialFooter,
                  children: [
                    for (final push in SocialPush.values)
                      AppListRowToggle(
                        title: _title(l10n, push),
                        value: state.isSocialPushEnabled(push),
                        onChanged: (isEnabled) =>
                            cubit.socialPushChanged(push, isEnabled: isEnabled),
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
                      onChanged: (isEnabled) =>
                          cubit.streakReminderChanged(isEnabled: isEnabled),
                    ),
                    if (state.isStreakReminderEnabled)
                      AppListRowButton(
                        title: l10n.notificationSettingsRemindAt,
                        accessory: AppListRowValue(hour(state.reminderHour)),
                        onPressed: () => _chooseHour(
                          context,
                          selected: state.reminderHour,
                          label: hour,
                        ),
                      ),
                    AppListRowToggle(
                      title: l10n.notificationSettingsWeeklyDigest,
                      value: state.isWeeklyDigestEnabled,
                      onChanged: (isEnabled) =>
                          cubit.weeklyDigestChanged(isEnabled: isEnabled),
                    ),
                    AppListRowToggle(
                      title: l10n.notificationSettingsWorkoutReminders,
                      value: state.isComeBackRemindersEnabled,
                      onChanged: (isEnabled) =>
                          cubit.comeBackRemindersChanged(isEnabled: isEnabled),
                    ),
                    AppListRowToggle(
                      title: l10n.notificationSettingsMealReminders,
                      value: state.isMealRemindersEnabled,
                      onChanged: (isEnabled) =>
                          cubit.mealRemindersChanged(isEnabled: isEnabled),
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
    final hour = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
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
