import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/profile/bloc/profile_bloc.dart';
import 'package:compound/settings/account/view/edit_profile_page.dart';
import 'package:compound/settings/view/settings_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:user_repository/user_repository.dart';

/// The signed-in user's own profile, opened over the tabs from the
/// [ProfileButton](package:compound/profile/view/profile_button.dart): who
/// they are, their units and weekly goal, and signing out.
class ProfilePage extends StatelessWidget {
  const new({super.key});

  static const path = '/profile';
  static const name = 'profile';

  @override
  Widget build(BuildContext context) {
    // The router only shows this page while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => ProfileBloc(
        userRepository: context.read<UserRepository>(),
        uid: state.user.uid,
      )..add(const ProfileSubscriptionRequested()),
      child: const ProfileView(),
    );
  }
}

class ProfileView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProfileBloc>().state;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(AppSymbols.settings),
            tooltip: context.l10n.settingsTitle,
            onPressed: () => context.pushNamed(SettingsPage.name),
          ),
        ],
      ),
      body: switch (state) {
        ProfileLoading() => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        ProfileLoaded(:final user) => _ProfileList(user: user),
        ProfileUnavailable() => const _ProfileList(),
      },
    );
  }
}

class _ProfileList extends StatelessWidget {
  const new({this.user});

  /// The profile, or null when there is none to show.
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = this.user;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.xl,
          children: [
            if (user == null)
              Text(
                l10n.profileUnavailable,
                style: AppTextStyles.rowDetail.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              )
            else ...[
              _ProfileHeader(user: user),
              AppSection(
                children: [
                  AppListRowButton(
                    title: l10n.profileEditProfile,
                    icon: AppSymbols.edit,
                    onPressed: () => context.pushNamed(EditProfilePage.name),
                  ),
                ],
              ),
              _AccountSection(user: user),
              _PreferencesSection(user: user),
            ],
            AppSection(
              children: [
                AppListRowButton(
                  title: l10n.signOutButton,
                  accessory: null,
                  onPressed: () =>
                      context.read<AppBloc>().add(const AppSignOutPressed()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const new({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = AppIconSize.hero.of(context);
    final placeholder = Icon(
      AppSymbols.profile,
      size: size,
      color: scheme.onSurfaceVariant,
    );
    // The picture the user chose in onboarding wins over the sign-in
    // provider's.
    final photoUrl = user.submittedProfileImage ?? user.photoUrl;
    final username = user.username;
    return Column(
      spacing: AppSpacing.s,
      children: [
        ExcludeSemantics(
          child: ClipOval(
            child: SizedBox.square(
              dimension: size,
              child: photoUrl == null
                  ? placeholder
                  : Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => placeholder,
                    ),
            ),
          ),
        ),
        Text(
          user.profileName ?? context.l10n.profileNoName,
          style: AppTextStyles.display.copyWith(color: scheme.onSurface),
          textAlign: TextAlign.center,
        ),
        if (username != null)
          Text(
            context.l10n.profileUsernameHandle(username),
            style: AppTextStyles.rowDetail.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _AccountSection extends StatelessWidget {
  const new({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = user.email ?? user.submittedEmail;
    final created = user.creationDate;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return AppSection(
      header: l10n.profileAccountHeader,
      children: [
        AppListRow(
          title: l10n.profileEmail,
          accessory: AppListRowValue(email ?? l10n.profileNotSet),
        ),
        AppListRow(
          title: l10n.profileUsername,
          accessory: AppListRowValue(user.username ?? l10n.profileNotSet),
        ),
        AppListRow(
          title: l10n.profileMemberSince,
          accessory: AppListRowValue(
            created == null
                ? l10n.profileNotSet
                : DateFormat.yMMMM(locale).format(created.toLocal()),
          ),
        ),
      ],
    );
  }
}

class _PreferencesSection extends StatelessWidget {
  const new({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final goal = user.weeklySessionGoal;
    return AppSection(
      header: l10n.profilePreferencesHeader,
      children: [
        AppListRow(
          title: l10n.profileWeeklyGoal,
          icon: AppSymbols.streak,
          accessory: AppListRowValue(
            goal == null ? l10n.profileNotSet : l10n.profileSessionsAWeek(goal),
          ),
        ),
        AppListRow(
          title: l10n.profileWeightUnits,
          icon: AppSymbols.scaleWeight,
          accessory: AppListRowValue(
            switch (user.submittedWeightUnitPreference) {
              WeightUnitPreference.kilograms => l10n.unitKilograms,
              WeightUnitPreference.pounds => l10n.unitPounds,
              null => l10n.profileNotSet,
            },
          ),
        ),
        AppListRow(
          title: l10n.profileHeightUnits,
          icon: AppSymbols.measurement,
          accessory: AppListRowValue(
            switch (user.submittedLengthUnitPreference) {
              LengthUnitPreference.centimeters => l10n.unitCentimeters,
              LengthUnitPreference.inches => l10n.unitInches,
              null => l10n.profileNotSet,
            },
          ),
        ),
        AppListRow(
          title: l10n.profileDistanceUnits,
          icon: AppSymbols.cardio,
          accessory: AppListRowValue(
            switch (user.submittedDistanceUnitPreference) {
              DistanceUnitPreference.kilometers => l10n.unitKilometers,
              DistanceUnitPreference.miles => l10n.unitMiles,
              null => l10n.profileNotSet,
            },
          ),
        ),
      ],
    );
  }
}

extension on UserModel {
  /// The name to show: the display name, else the first and last names.
  String? get profileName {
    if (displayName case final name? when name.isNotEmpty) return name;
    final parts = [
      firstName ?? submittedFirstName,
      lastName ?? submittedLastName,
    ].whereType<String>().where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }
}
