import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/gym_profiles/cubit/gym_profiles_cubit.dart';
import 'package:compound/gym_profiles/view/gym_profile_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/training/gym_setup_cubit.dart';
import 'package:compound/training_library/bloc/training_library_bloc.dart';
import 'package:compound/training_library/models/training_library.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// The user's gyms, the usual one first (Swift `GymProfilesView`), from
/// Settings. A gym opens its editor; a new one opens a blank gym.
class GymProfilesPage extends StatelessWidget {
  const new({super.key});

  /// Under Settings: `/profile/settings/gym-profiles`.
  static const path = 'gym-profiles';
  static const name = 'gymProfiles';

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppBloc>().state;
    if (app is! AppAuthenticated) return const SizedBox.shrink();
    return TrainingLibraryProvider(
      uid: app.user.uid,
      child: BlocProvider(
        create: (context) => GymProfilesCubit(
          uid: app.user.uid,
          library: context.read<TrainingLibraryRepository>(),
          setup: context.read<TrainingSetupService>(),
          analytics: context.read<AnalyticsRepository>(),
        ),
        child: const GymProfilesView(),
      ),
    );
  }
}

class GymProfilesView extends StatelessWidget {
  const new({super.key});

  void _add(BuildContext context, AppAuthenticated app) => unawaited(
    GymProfilePage.push(
      context,
      newGymProfile(
        authorId: app.user.uid,
        name: '',
        now: DateTime.now(),
        weightUnit: app.profile?.submittedWeightUnitPreference,
        kilogramStackName: context.l10n.onboardingKilogramStack,
      ),
    ),
  );

  Future<void> _delete(BuildContext context, GymProfileModel gym) async {
    final l10n = context.l10n;
    final cubit = context.read<GymProfilesCubit>();
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.gymDeleteProfileTitle),
        content: Text(l10n.gymDeleteProfileMessage(gym.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.gymCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.gymDelete),
          ),
        ],
      ),
    );
    if (delete ?? false) await cubit.delete(gym);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final app = context.watch<AppBloc>().state;
    if (app is! AppAuthenticated) return const SizedBox.shrink();
    final gyms = switch (context.watch<TrainingLibraryBloc>().state) {
      TrainingLibraryLoaded(:final library) => library.gyms,
      _ => const <GymProfileModel>[],
    };
    final favouriteId = app.profile?.submittedFavouriteGymProfileId;
    final favourite = gyms.where((gym) => gym.id == favouriteId).firstOrNull;
    final others = [
      for (final gym in gyms)
        if (gym.id != favouriteId) gym,
    ];
    return BlocListener<GymProfilesCubit, GymProfilesStatus>(
      listener: (context, status) => switch (status) {
        GymProfilesStatus.deleteFailure => unawaited(
          showFailureAlert(context, l10n.gymUnableToDelete, l10n.gymTryAgain),
        ),
        GymProfilesStatus.favouriteFailure => unawaited(
          showFailureAlert(
            context,
            l10n.gymUnableToFavourite,
            l10n.gymTryAgain,
          ),
        ),
        GymProfilesStatus.idle => null,
      },
      child: AppScaffold(
        appBar: AppBar(
          title: Text(l10n.gymProfilesTitle),
          actions: [
            IconButton(
              icon: const Icon(AppSymbols.add),
              tooltip: l10n.gymAddProfileLabel,
              onPressed: () => _add(context, app),
            ),
          ],
        ),
        body: SafeArea(
          child: gyms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LibraryEmptyState(
                        icon: AppSymbols.equipment,
                        title: l10n.gymNoProfiles,
                        message: l10n.gymNoProfilesMessage,
                      ),
                      TextButton(
                        onPressed: () => _add(context, app),
                        child: Text(l10n.gymAddProfile),
                      ),
                    ],
                  ),
                )
              : LibrarySections(
                  children: [
                    if (favourite != null)
                      AppSection(
                        header: l10n.gymFavouriteProfile,
                        children: [
                          _GymRow(
                            gym: favourite,
                            onDelete: () =>
                                unawaited(_delete(context, favourite)),
                          ),
                        ],
                      ),
                    if (others.isNotEmpty)
                      AppSection(
                        header: l10n.gymCount(others.length),
                        children: [
                          for (final gym in others)
                            _GymRow(
                              gym: gym,
                              onDelete: () => unawaited(_delete(context, gym)),
                              onFavourite: () => unawaited(
                                context.read<GymProfilesCubit>().favourite(gym),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A gym: tap to edit; swipe to delete, the other way to make it the
/// usual gym, with the same two as screen reader actions.
class _GymRow extends StatelessWidget {
  const new({required this.gym, required this.onDelete, this.onFavourite});

  final GymProfileModel gym;
  final VoidCallback onDelete;
  final VoidCallback? onFavourite;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final onFavourite = this.onFavourite;
    Widget background(Color color, IconData icon, Alignment alignment) =>
        ColoredBox(
          color: color,
          child: Align(
            alignment: alignment,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: Icon(icon, color: scheme.onPrimary),
            ),
          ),
        );
    return Dismissible(
      key: ValueKey(gym.id),
      direction: onFavourite == null
          ? DismissDirection.endToStart
          : DismissDirection.horizontal,
      background: background(
        scheme.primary,
        AppSymbols.favourite,
        Alignment.centerLeft,
      ),
      secondaryBackground: background(
        scheme.error,
        AppSymbols.delete,
        Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          onDelete();
        } else {
          onFavourite?.call();
        }
        return false;
      },
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: l10n.gymDelete): onDelete,
          CustomSemanticsAction(label: l10n.gymFavourite): ?onFavourite,
        },
        child: AppListRowButton(
          key: Key('GymProfiles.${gym.id}'),
          title: gym.name,
          subtitle: l10n.editorActiveEquipment(
            TrainingLibrary.activeEquipmentCount(gym),
          ),
          icon: gym.imageUrl == null ? AppSymbols.gym : null,
          thumbnail: gym.imageUrl == null
              ? null
              : StoredThumbnail(gym.imageUrl),
          onPressed: () => unawaited(GymProfilePage.push(context, gym)),
        ),
      ),
    );
  }
}

/// Naming a new gym, the first step of setting one up (Swift
/// `CreateGymProfileView`), from Choose Gym Profile; onboarding's gym step
/// is the same with the onboarding frame. Continue opens the gym's
/// equipment, and the gym's own Continue comes back past this screen.
class CreateGymProfilePage extends StatelessWidget {
  const new({super.key});

  /// Pushes the screen.
  static Future<void> push(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const CreateGymProfilePage()));

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppBloc>().state;
    final profile = app is AppAuthenticated ? app.profile : null;
    if (profile == null) return const SizedBox.shrink();
    final kilogramStackName = context.l10n.onboardingKilogramStack;
    return BlocProvider(
      create: (context) => GymSetupCubit(
        analyticsRepository: context.read<AnalyticsRepository>(),
        profile: profile,
        kilogramStackName: kilogramStackName,
      ),
      child: const CreateGymProfileView(),
    );
  }
}

class CreateGymProfileView extends StatelessWidget {
  const new({super.key});

  Future<void> _continue(BuildContext context) async {
    final draft = context.read<GymSetupCubit>().draft();
    if (draft == null) return;
    final done = await GymProfilePage.push(context, draft, continues: true);
    if ((done ?? false) && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<GymSetupCubit>();
    final canSave = context.select<GymSetupCubit, bool>(
      (cubit) => cubit.state.canSave,
    );
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.onboardingGymTitle)),
      body: SafeArea(
        bottom: false,
        child: LibrarySections(
          children: [
            AppSection(
              header: l10n.onboardingGymHeader,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                  child: TextField(
                    key: const Key('CreateGymProfile.name'),
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l10n.onboardingGymName,
                      border: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: cubit.nameChanged,
                    onSubmitted: (_) => unawaited(_continue(context)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomCta(
        children: [
          AppCtaButton(
            label: l10n.onboardingContinue,
            onPressed: canSave ? () => unawaited(_continue(context)) : null,
          ),
        ],
      ),
    );
  }
}
