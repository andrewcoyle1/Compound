import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/coach/coach.dart';
import 'package:compound/gym_profiles/view/gym_profiles_page.dart';
import 'package:compound/integrations/view/integrations_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/account/view/delete_account_page.dart';
import 'package:compound/settings/cubit/settings_cubit.dart';
import 'package:compound/settings/general/view/about_page.dart';
import 'package:compound/settings/general/view/customise_analytics_page.dart';
import 'package:compound/settings/general/view/legal_page.dart';
import 'package:compound/settings/general/view/methods_and_sources_page.dart';
import 'package:compound/settings/general/view/notification_settings_page.dart';
import 'package:compound/settings/general/view/units_page.dart';
import 'package:compound/settings/nutrition/view/expenditure_settings_page.dart';
import 'package:compound/settings/nutrition/view/food_log_settings_page.dart';
import 'package:compound/settings/nutrition/view/strategy_settings_page.dart';
import 'package:compound/settings/training/view/workout_settings_page.dart';
import 'package:compound/social/invite/invite_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Where the Support row sends people (Swift `Constants.supportEmail`).
const supportEmail = 'andrewcoyle.1@outlook.com';

/// The settings list behind the profile's gear (Swift `SettingsView`), in
/// Swift's sections and order. Rows whose screens are not built yet are
/// left out rather than shown dead.
class SettingsPage extends StatelessWidget {
  const new({super.key});

  /// Under the profile: `/profile/settings`.
  static const path = 'settings';
  static const name = 'settings';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SettingsCubit(
        analytics: context.read<AnalyticsRepository>(),
        auth: context.read<AuthRepository>(),
      )..appeared(),
      child: const SettingsView(),
    );
  }
}

class SettingsView extends StatefulWidget {
  const new({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final SettingsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<SettingsCubit>();
  }

  @override
  void dispose() {
    _cubit.disappeared();
    super.dispose();
  }

  void _open(String name) => unawaited(context.pushNamed(name));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    final cubit = context.read<SettingsCubit>();
    return BlocListener<SettingsCubit, SettingsStatus>(
      listener: (context, status) {
        if (status != SettingsStatus.signOutFailure) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.settingsSignOutFailed)));
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.settingsTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              AppSection(
                header: l10n.settingsGeneralHeader,
                children: [
                  AppListRowButton(
                    title: l10n.settingsNotificationSettings,
                    icon: AppSymbols.notifications,
                    onPressed: () {
                      cubit.notificationSettingsPressed();
                      _open(NotificationSettingsPage.name);
                    },
                  ),
                  AppListRowButton(
                    title: l10n.settingsIntegrations,
                    icon: AppSymbols.integrations,
                    onPressed: () => _open(IntegrationsPage.name),
                  ),
                  // The coach's chats and the permission behind them.
                  AppListRowButton(
                    title: l10n.coachTitle,
                    icon: AppSymbols.coach,
                    onPressed: () => _open(CoachChatsPage.name),
                  ),
                  AppListRowButton(
                    title: l10n.settingsUnits,
                    icon: AppSymbols.measurement,
                    onPressed: () => _open(UnitsPage.name),
                  ),
                  AppListRowButton(
                    title: l10n.settingsAnalytics,
                    icon: AppSymbols.analytics,
                    onPressed: () => _open(CustomiseAnalyticsPage.name),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSection(
                header: l10n.settingsNutritionHeader,
                children: [
                  AppListRowButton(
                    title: l10n.settingsFoodLog,
                    icon: AppSymbols.food,
                    onPressed: () => _open(FoodLogSettingsPage.name),
                  ),
                  AppListRowButton(
                    title: l10n.settingsExpenditure,
                    icon: AppSymbols.expenditure,
                    onPressed: () => _open(ExpenditureSettingsPage.name),
                  ),
                  AppListRowButton(
                    title: l10n.settingsStrategy,
                    icon: AppSymbols.strategy,
                    onPressed: () => _open(StrategySettingsPage.name),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSection(
                header: l10n.settingsTrainingHeader,
                children: [
                  AppListRowButton(
                    title: l10n.gymProfilesTitle,
                    icon: AppSymbols.gym,
                    onPressed: () => _open(GymProfilesPage.name),
                  ),
                  AppListRowButton(
                    title: l10n.settingsWorkoutSettings,
                    icon: AppSymbols.workout,
                    onPressed: () => _open(WorkoutSettingsPage.name),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSection(
                header: l10n.settingsCommunityHeader,
                children: [
                  AppListRowButton(
                    title: l10n.inviteCardTitle,
                    icon: AppSymbols.invite,
                    onPressed: () {
                      final app = context.read<AppBloc>().state;
                      if (app is! AppAuthenticated) return;
                      unawaited(
                        context.read<InviteCubit>().shareRequested(
                          app.user.uid,
                          pressedEvent: 'ProfileView_InviteFriend_Press',
                        ),
                      );
                    },
                  ),
                  AppListRowButton(
                    title: l10n.settingsSupport,
                    icon: AppSymbols.help,
                    onPressed: () {
                      cubit.supportPressed();
                      _showSupport(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSection(
                header: l10n.settingsOtherHeader,
                children: [
                  AppListRowButton(
                    title: l10n.settingsLegal,
                    icon: AppSymbols.legal,
                    onPressed: () => _open(LegalPage.name),
                  ),
                  AppListRowButton(
                    title: l10n.settingsMethodsAndSources,
                    icon: AppSymbols.knowledgeBase,
                    onPressed: () => _open(MethodsAndSourcesPage.name),
                  ),
                  AppListRowButton(
                    title: l10n.settingsAbout,
                    icon: AppSymbols.info,
                    onPressed: () => _open(AboutPage.name),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _SecuritySection(state: state),
            ],
          ),
        ),
      ),
    );
  }

  /// Swift opens a mail draft, and falls back to this alert when it can't;
  /// the app has no way to open mail yet, so it always says where to write.
  void _showSupport(BuildContext context) {
    final l10n = context.l10n;
    showAdaptiveDialog<void>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(l10n.settingsSupport),
        content: SelectableText(l10n.settingsSupportMessage(supportEmail)),
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

class _SecuritySection extends StatelessWidget {
  const new({required this.state});

  final AppAuthenticated state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SettingsCubit>();
    final signingOut = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state == SettingsStatus.signingOut,
    );
    final method = switch (SignInMethod.of(state.user)) {
      SignInMethod.notSaved => l10n.settingsSignInNotSaved,
      SignInMethod.apple => l10n.settingsSignInApple,
      SignInMethod.google => l10n.settingsSignInGoogle,
      SignInMethod.unknown => '—',
    };
    return AppSection(
      header: l10n.settingsSecurityHeader,
      children: [
        AppListRow(
          title: l10n.settingsSignInMethod,
          accessory: AppListRowValue(method),
        ),
        AppListRow(
          title: l10n.profileEmail,
          accessory: AppListRowValue(
            state.profile?.email ?? l10n.settingsEmailNotProvided,
          ),
        ),
        // Signing an anonymous account out locks its data away for good,
        // so Swift offers it the upgrade instead; that waits for linking
        // from Settings.
        if (!state.user.isAnonymous)
          AppListRowButton(
            title: l10n.signOutButton,
            accessory: null,
            onPressed: signingOut ? null : cubit.signOutPressed,
          ),
        AppListRowButton(
          title: l10n.settingsDeleteAccount,
          accessory: null,
          tint: Theme.of(context).colorScheme.error,
          onPressed: () {
            cubit.deleteAccountPressed();
            unawaited(context.pushNamed(DeleteAccountPage.name));
          },
        ),
      ],
    );
  }
}
