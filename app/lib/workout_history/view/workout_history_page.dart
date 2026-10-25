import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/first_weekday.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_history/bloc/workout_history_bloc.dart';
import 'package:compound/workout_history/view/workout_session_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// The signed-in user's finished workouts, newest first, pushed from the
/// Training tab's Library.
class WorkoutHistoryPage extends StatelessWidget {
  const new({super.key});

  /// The path under the Training tab.
  static const path = 'history';

  /// The route name.
  static const name = 'workoutHistory';

  @override
  Widget build(BuildContext context) {
    // The router only shows this page while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    final firstDayOfWeek = firstDayOfWeekIndex(context);
    return BlocProvider(
      create: (context) => WorkoutHistoryBloc(
        repository: context.read<WorkoutSessionRepository>(),
        uid: state.user.uid,
        firstDayOfWeek: firstDayOfWeek,
      )..add(const WorkoutHistorySubscriptionRequested()),
      child: const WorkoutHistoryView(),
    );
  }
}

class WorkoutHistoryView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkoutHistoryBloc>().state;
    return AppScaffold(
      appBar: AppBar(title: Text(context.l10n.workoutHistoryTitle)),
      body: switch (state) {
        WorkoutHistoryLoading() => AppLoadingView(
          label: context.l10n.launchLoading,
        ),
        WorkoutHistoryFailure() => const _Failure(),
        WorkoutHistoryLoaded(:final entries) when entries.isEmpty =>
          const _Empty(),
        WorkoutHistoryLoaded(:final entries) => _List(entries: entries),
      },
    );
  }
}

class _List extends StatelessWidget {
  const new({required this.entries});

  final List<WorkoutHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Semantics(
        header: true,
        child: Row(
          spacing: AppSpacing.s,
          children: [
            Expanded(
              child: Text(
                context.l10n.workoutHistoryCompletedHeader,
                style: AppTextStyles.sectionTitle.secondary(context),
              ),
            ),
            Text(
              AppFormat.number(entries.length, locale: locale),
              style: AppTextStyles.metricSmall.secondary(context),
            ),
          ],
        ),
      ),
    );
    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.l),
        itemCount: entries.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.m),
        itemBuilder: (_, index) =>
            index == 0 ? header : WorkoutSessionCard(entry: entries[index - 1]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppEmptyState(
      icon: AppSymbols.history,
      title: l10n.workoutHistoryEmptyTitle,
      description: l10n.workoutHistoryEmptyMessage,
    );
  }
}

class _Failure extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppErrorState(
      title: l10n.workoutHistoryLoadFailure,
      actionLabel: l10n.tryAgainButton,
      onAction: () => context.read<WorkoutHistoryBloc>().add(
        const WorkoutHistorySubscriptionRequested(),
      ),
    );
  }
}
