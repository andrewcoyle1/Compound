import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/first_weekday.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/dev/dev_settings_cubit.dart';
import 'package:compound/settings/general/view/on_dispose.dart';
import 'package:compound/sharing/share_card/share_card_content.dart';
import 'package:compound/sharing/share_card/share_card_renderer.dart';
import 'package:compound/sharing/share_card/workout_share_card.dart';
import 'package:compound/sharing/share_sheet.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// Developer tools (Swift `DevSettingsView`), behind a Settings row in the
/// development and staging builds; never in production.
class DevSettingsPage extends StatelessWidget {
  const new({super.key});

  /// Under Settings: `/profile/settings/developer`.
  static const path = 'developer';
  static const name = 'settingsDeveloper';

  /// Whether this build offers the tools: every flavor but production, as
  /// Swift's `#if DEV || MOCK`.
  static bool get isAvailable => appFlavor != 'production';

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => DevSettingsCubit(
        auth: context.read<AuthRepository>(),
        purchases: context.read<PurchasesRepository>(),
        sessions: context.read<WorkoutSessionRepository>(),
        library: context.read<TrainingLibraryRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        uid: state.user.uid,
      )..appeared(),
      child: const DevSettingsView(),
    );
  }
}

class DevSettingsView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<DevSettingsCubit>();
    final dev = context.watch<DevSettingsCubit>().state;
    final app = context.watch<AppBloc>().state;
    final version = context.read<AppVersion?>();
    final active = context.select<ActiveWorkoutCubit, WorkoutSessionModel?>(
      (cubit) => cubit.state.session,
    );
    final user = app is AppAuthenticated ? app.user : null;
    final profile = app is AppAuthenticated ? app.profile : null;
    const gap = SizedBox(height: AppSpacing.xl);
    return OnDispose(
      onDispose: cubit.disappeared,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.devSettingsTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              if (dev.simulatePremium case final premium?) ...[
                AppSection(
                  header: l10n.settingsSubscription,
                  footer: l10n.devSettingsSimulatePremiumFooter,
                  children: [
                    AppListRowToggle(
                      title: l10n.devSettingsSimulatePremium,
                      value: premium,
                      onChanged: (value) =>
                          cubit.simulatePremiumChanged(value: value),
                    ),
                  ],
                ),
                gap,
              ],
              AppSection(
                header: l10n.devSettingsDebugActions,
                footer: l10n.devSettingsSignOutFooter,
                children: [
                  AppListRowButton(
                    title: l10n.signOutButton,
                    accessory: null,
                    tint: Theme.of(context).colorScheme.error,
                    onPressed: () => unawaited(_signOut(context)),
                  ),
                ],
              ),
              gap,
              AppSection(
                header: l10n.devSettingsShareCard,
                footer: l10n.devSettingsExportShareCardsFooter,
                children: [
                  AppListRowButton(
                    title: l10n.devSettingsExportShareCards,
                    accessory: null,
                    onPressed: () => unawaited(_exportShareCards(context)),
                  ),
                ],
              ),
              gap,
              _Values(l10n.devSettingsAuthInfo, devAuthParameters(user)),
              gap,
              _Values(l10n.devSettingsUserInfo, devUserParameters(profile)),
              gap,
              _Values(l10n.devSettingsDeviceInfo, [
                ('app_build', version?.build ?? '—'),
                ('app_flavor', appFlavor ?? '—'),
                ('app_version', version?.version ?? '—'),
                ('platform', Theme.of(context).platform.name),
              ]),
              gap,
              AppSection(
                header: l10n.devSettingsActiveSession,
                children: [
                  if (active == null)
                    AppListRow(title: l10n.devSettingsNoActiveSession)
                  else
                    ..._sessionRows(active),
                ],
              ),
              gap,
              const _SessionLookup(),
              gap,
              _Values(l10n.devSettingsLibrary, [
                (
                  l10n.devSettingsExercises,
                  '${PrebuiltCatalogue.instance.exercises.length + //
                      dev.userExercises}',
                ),
                (
                  l10n.devSettingsWorkoutTemplates,
                  '${PrebuiltCatalogue.instance.workoutTemplates.length + //
                      dev.userWorkoutTemplates}',
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (await context.read<DevSettingsCubit>().signOutPressed()) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.settingsSignOutFailed)));
  }
}

/// Draws the sample session's card in both formats and opens the share
/// sheet with them (Swift's `onSaveShareCardsPressed`, which saves them to
/// Photos; the sheet offers that). The session is read against the rest of
/// the sample history, so the card carries records and a weekly count.
Future<void> _exportShareCards(BuildContext context) async {
  final l10n = context.l10n;
  final shareSheet = context.read<ShareSheet>();
  final messenger = ScaffoldMessenger.of(context);
  final now = DateTime.now();
  final week = sampleWorkoutSessions(uid: sampleUserId, now: now);
  final content = ShareCardContent.fromHistory(
    l10n,
    week.first,
    author: sampleUser(now: now),
    history: [
      ...sampleEarlierWorkoutSessions(uid: sampleUserId, now: now),
      ...week,
    ],
    firstDayOfWeek: firstDayOfWeekIndex(context),
    locale: Localizations.localeOf(context).toLanguageTag(),
  );
  final accent = Theme.of(context).colorScheme.primary;
  final avatar = await loadShareCardImage(context, content.avatarUrl);
  final images = <(String, Uint8List)>[];
  for (final format in ShareCardFormat.values) {
    if (!context.mounted) return;
    final png = await renderShareCard(
      context,
      WorkoutShareCard(
        content: content,
        format: format,
        accent: accent,
        l10n: l10n,
        avatar: avatar,
      ),
      size: format.size,
    );
    if (png != null) images.add(('compound-${format.name}.png', png));
  }
  if (!context.mounted) return;
  if (images.isEmpty) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.shareImageFailed)));
    return;
  }
  await shareSheet.shareImages(context, images);
}

/// A session's ids, dates and progress, as Swift's debug rows. The labels
/// are field names, so they are not translated.
List<Widget> _sessionRows(WorkoutSessionModel session) {
  final sets = [for (final exercise in session.exercises) ...exercise.sets];
  final done = sets.where((set) => set.completedAt != null).length;
  return [
    for (final (key, value) in [
      ('session_id', session.id),
      ('name', session.name),
      ('template_id', session.workoutTemplateId ?? 'nil'),
      ('plan_id', session.mesocycleId ?? 'nil'),
      ('created', '${session.dateCreated}'),
      ('ended', session.endedAt?.toString() ?? 'nil (in progress)'),
      ('exercises', '${session.exercises.length}'),
      ('sets', '$done/${sets.length}'),
    ])
      AppListRow(title: key, subtitle: value),
  ];
}

class _Values extends StatelessWidget {
  const new(this.header, this.values);

  final String header;
  final List<(String, String)> values;

  @override
  Widget build(BuildContext context) => AppSection(
    header: header,
    children: [
      for (final (key, value) in values)
        AppListRow(title: key, subtitle: value),
    ],
  );
}

/// Fetch a session by id (Swift's Firebase Test).
class _SessionLookup extends StatefulWidget {
  const new();

  @override
  State<_SessionLookup> createState() => _SessionLookupState();
}

class _SessionLookupState extends State<_SessionLookup> {
  final _id = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<DevSettingsCubit>().state;
    final session = state.fetchedSession;
    final error = state.fetchError;
    return AppSection(
      header: l10n.devSettingsFetchSession,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: TextField(
            controller: _id,
            decoration: InputDecoration(labelText: l10n.devSettingsSessionId),
            onChanged: (_) => setState(() {}),
          ),
        ),
        AppListRowButton(
          title: l10n.devSettingsFetch,
          accessory: null,
          onPressed: _id.text.trim().isEmpty || state.isFetchingSession
              ? null
              : () => unawaited(
                  context.read<DevSettingsCubit>().fetchSession(_id.text),
                ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: AppInlineMessage(
              kind: AppInlineMessageKind.error,
              kindLabel: l10n.errorLabel,
              text: error == DevSettingsState.notFound
                  ? l10n.devSettingsSessionNotFound
                  : error,
            ),
          ),
        if (session != null) ..._sessionRows(session),
      ],
    );
  }
}
