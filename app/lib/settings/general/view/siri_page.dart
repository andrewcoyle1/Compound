import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/integrations/link_opener.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/general/cubit/screen_tracking_cubit.dart';
import 'package:compound/settings/general/view/on_dispose.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The App Shortcuts the app ships and what to say for each (Swift
/// `SiriView`): they work in Siri, Spotlight and Shortcuts with no setup.
/// iOS only.
class SiriPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'siri';
  static const name = 'settingsSiri';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ScreenTrackingCubit(
        analytics: context.read<AnalyticsRepository>(),
        screen: 'SiriView',
      )..appeared(),
      child: const SiriView(),
    );
  }
}

class SiriView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OnDispose(
      onDispose: context.read<ScreenTrackingCubit>().disappeared,
      child: AppScaffold(
        appBar: AppBar(title: Text(l10n.settingsSiri)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              AppSection(
                header: l10n.siriAskHeader,
                children: [
                  for (final (title, phrase, icon) in [
                    (
                      l10n.siriStartWorkout,
                      l10n.siriStartWorkoutPhrase,
                      AppSymbols.start,
                    ),
                    (
                      l10n.siriLogWeight,
                      l10n.siriLogWeightPhrase,
                      AppSymbols.scaleWeight,
                    ),
                    (
                      l10n.siriWorkoutsThisWeek,
                      l10n.siriWorkoutsThisWeekPhrase,
                      AppSymbols.calendar,
                    ),
                    (
                      l10n.siriTodaysWorkout,
                      l10n.siriTodaysWorkoutPhrase,
                      AppSymbols.workout,
                    ),
                    (
                      l10n.siriRecipes,
                      l10n.siriRecipesPhrase,
                      AppSymbols.recipe,
                    ),
                  ])
                    MergeSemantics(
                      child: AppListRow(
                        title: title,
                        subtitle: phrase,
                        icon: icon,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSection(
                footer: l10n.siriFooter,
                children: [
                  AppListRowButton(
                    title: l10n.siriOpenShortcuts,
                    icon: AppSymbols.openExternally,
                    accessory: null,
                    onPressed: () => unawaited(
                      context.read<LinkOpener>().open(
                        Uri.parse('shortcuts://'),
                      ),
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
