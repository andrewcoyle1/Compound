import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_weight/view/quick_weigh_in.dart';
import 'package:compound/programs/logic/todays_workout.dart';
import 'package:compound/programs/programs.dart';
import 'package:compound/today/bloc/today_bloc.dart';
import 'package:compound/today/view/day_checklist_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The top of today's chat, built by the app rather than the coach: the
/// date, then the day's checklist as Today shows it, live all day. Each
/// item opens its screen as on Today; the weigh-in, until it is done, can
/// also be logged in place. Celebrating a finished item stays Today's.
class CoachDayCard extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TodayBloc>().state;
    final programs = context.watch<ProgramsCubit>().state;
    final workout = programs.status == ProgramsStatus.loaded
        ? TodaysWorkout.of(programs, state.now)
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.m,
        children: [
          Semantics(
            header: true,
            child: Text(
              AppFormat.date(
                state.now,
                style: AppDateStyle.weekdayDayMonthLong,
                locale: context.dateLocale,
              ),
              style: AppTextStyles.sectionTitle,
            ),
          ),
          switch (state.status) {
            TodayStatus.loading => AppPlaceholder(
              height: MediaQuery.textScalerOf(context)
                  .scale(AppChartHeight.compact),
              radius: AppRadius.xl,
              semanticLabel: context.l10n.launchLoading,
            ),
            // Today says the day could not be read; here the chat goes on.
            TodayStatus.failure => const SizedBox.shrink(),
            TodayStatus.loaded => DayChecklistCard(
              checklist: state.checklistWith(planned: workout?.today?.dayPlan),
              stepGoal: state.stepGoal,
              unit: state.usesPounds
                  ? AppWeightUnit.pounds
                  : AppWeightUnit.kilograms,
              workout: workout,
              weighIn: const QuickWeighIn(),
            ),
          },
        ],
      ),
    );
  }
}
