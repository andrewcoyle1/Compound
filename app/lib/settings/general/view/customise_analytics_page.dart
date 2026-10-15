import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/progress/logic/progress_overview.dart';
import 'package:compound/settings/general/cubit/customise_analytics_cubit.dart';
import 'package:compound/settings/general/view/on_dispose.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Which sections the Progress tab shows (Swift `CustomiseAnalyticsView`).
/// Each switch saves as it changes.
class CustomiseAnalyticsPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'analytics';
  static const name = 'settingsAnalytics';

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => CustomiseAnalyticsCubit(
        body: context.read<BodyRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        uid: state.user.uid,
      )..appeared(),
      child: const CustomiseAnalyticsView(),
    );
  }
}

class CustomiseAnalyticsView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CustomiseAnalyticsCubit>();
    final state = context.watch<CustomiseAnalyticsCubit>().state;
    return OnDispose(
      onDispose: cubit.disappeared,
      child: BlocListener<CustomiseAnalyticsCubit, CustomiseAnalyticsState>(
        listenWhen: (_, state) => state.saveFailed,
        listener: (context, _) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.unitsSaveFailed))),
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.customiseAnalyticsTitle)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                AppSection(
                  header: l10n.customiseAnalyticsSectionsHeader,
                  footer: l10n.customiseAnalyticsFooter,
                  children: [
                    for (final section in ProgressSection.values)
                      AppListRowToggle(
                        title: _title(l10n, section),
                        icon: _icon(section),
                        value: state.isVisible(section),
                        onChanged: state.canHide(section)
                            ? (isVisible) => cubit.visibilityChanged(
                                section,
                                isVisible: isVisible,
                              )
                            : null,
                      ),
                  ],
                ),
                if (state.hiddenCount > 0) ...[
                  const SizedBox(height: AppSpacing.xl),
                  AppSection(
                    children: [
                      AppListRowButton(
                        title: l10n.customiseAnalyticsShowAll,
                        accessory: null,
                        onPressed: cubit.showAllPressed,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _title(AppLocalizations l10n, ProgressSection section) =>
      switch (section) {
        ProgressSection.insightsAndAnalytics => l10n.progressInsightsHeader,
        ProgressSection.habits => l10n.progressHabitsHeader,
        ProgressSection.nutrition => l10n.progressNutritionHeader,
        ProgressSection.bodyMetrics => l10n.progressBodyMetricsHeader,
        ProgressSection.muscleGroups => l10n.customiseAnalyticsMuscleGroups,
        ProgressSection.exercises => l10n.customiseAnalyticsExercises,
      };

  static IconData _icon(ProgressSection section) => switch (section) {
    ProgressSection.insightsAndAnalytics => AppSymbols.analytics,
    ProgressSection.habits => AppSymbols.habits,
    ProgressSection.nutrition => AppSymbols.meal,
    ProgressSection.bodyMetrics => AppSymbols.measurement,
    ProgressSection.muscleGroups => AppSymbols.muscleGroup,
    ProgressSection.exercises => AppSymbols.equipment,
  };
}
