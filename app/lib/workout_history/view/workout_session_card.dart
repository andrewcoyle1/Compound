import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_history/bloc/workout_history_bloc.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound/workout_session_detail/view/workout_session_detail_page.dart';
import 'package:compound_models/compound_models.dart';
import 'package:go_router/go_router.dart';

/// One finished workout: its name and date, its highlights, totals and
/// exercises, and its note. Opens the session detail. A port of the Swift
/// app's `WorkoutSessionRowView`; the history shows it alone, and the
/// social feed adds the author over it and likes and comments under it.
class WorkoutSessionCard extends StatelessWidget {
  const new({
    required this.entry,
    this.header,
    this.footer,
    this.onPressed,
    this.showsNote = true,
    super.key,
  });

  /// The workout and its highlights.
  final WorkoutHistoryEntry entry;

  /// Over the workout, in place of its date: the feed's author.
  final Widget? header;

  /// Under the workout, after a divider: the feed's likes and comments.
  final Widget? footer;

  /// What a tap on the workout does; the history's session detail when
  /// null.
  final VoidCallback? onPressed;

  /// Whether the note shows: a note is its author's private reminder, so
  /// a follower's feed leaves it out.
  final bool showsNote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final session = entry.session;
    final isLargeText =
        MediaQuery.textScalerOf(context).scale(1) >=
        AppListRow.accessibilityTextScale;
    final volume = WorkoutText.sessionVolume(session, locale: locale);
    final duration = session.activeDuration;
    final note = session.notes?.trim();
    final secondary = AppTextStyles.rowDetail.secondary(context);

    final header = this.header;
    final footer = this.footer;
    final content = MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap:
              onPressed ??
              () => context.goNamed(
                WorkoutSessionDetailPage.name,
                pathParameters: {
                  WorkoutSessionDetailPage.sessionIdParameter: session.id,
                },
              ),
          child: Padding(
            padding: header == null
                ? const EdgeInsets.all(AppSpacing.l)
                : const EdgeInsets.fromLTRB(
                    AppSpacing.l,
                    AppSpacing.m,
                    AppSpacing.l,
                    AppSpacing.l,
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.m,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xxs,
                  children: [
                    Text(session.name, style: AppTextStyles.sectionTitle),
                    if (header == null)
                      Text(
                        AppFormat.dateTime(
                          session.dateCreated.toLocal(),
                          use24HourFormat: context.use24HourFormat,
                          style: AppDateStyle.weekdayMedium,
                          locale: context.dateLocale,
                        ),
                        style: secondary,
                      ),
                  ],
                ),
                _Highlights(entry: entry),
                Wrap(
                  spacing: AppSpacing.xl,
                  runSpacing: AppSpacing.s,
                  children: [
                    AppStat(
                      value: AppFormat.number(
                        session.doneExercises.length,
                        locale: locale,
                      ),
                      label: l10n.statExercises,
                      size: AppStatSize.small,
                    ),
                    AppStat(
                      value: AppFormat.number(
                        session.loggedSetCount,
                        locale: locale,
                      ),
                      label: l10n.statSets,
                      size: AppStatSize.small,
                    ),
                    if (volume != null)
                      AppStat(
                        value: volume,
                        label: l10n.statVolume,
                        size: AppStatSize.small,
                      ),
                    if (duration != null)
                      AppStat(
                        value: AppFormat.duration(duration),
                        label: l10n.statDuration,
                        size: AppStatSize.small,
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.xs,
                  children: [
                    for (final exercise in session.doneExercises)
                      _ExerciseLine(
                        name: exercise.name,
                        sets: WorkoutText.exerciseSets(
                          l10n,
                          exercise,
                          session,
                          locale: locale,
                        ),
                        isLargeText: isLargeText,
                      ),
                  ],
                ),
                if (showsNote && note != null && note.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.xs,
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          AppSymbols.note,
                          size: AppIconSize.small.of(context),
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          note,
                          style: AppTextStyles.label.secondary(context),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
    if (header == null && footer == null) return AppCard(child: content);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.l,
                AppSpacing.l,
                0,
              ),
              child: header,
            ),
          content,
          if (footer != null) ...[
            const Divider(
              height: 1,
              indent: AppSpacing.l,
              endIndent: AppSpacing.l,
            ),
            footer,
          ],
        ],
      ),
    );
  }
}

/// Records first, then the streak, then the weekly count, each a capsule.
/// Wraps rather than truncates.
class _Highlights extends StatelessWidget {
  const new({required this.entry});

  final WorkoutHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final streak = WorkoutText.streak(l10n, entry.session.weekStreakCount);
    final weekly = WorkoutText.weeklyWorkout(l10n, entry.weeklyWorkoutNumber);
    final capsules = [
      for (final record in entry.personalRecords)
        _Capsule(
          text: l10n.highlightPersonalRecord(
            record.exerciseName,
            WorkoutText.recordDetail(l10n, record, locale: locale),
          ),
          icon: AppSymbols.personalRecord,
          tint: colors.personalRecord,
        ),
      if (streak != null)
        _Capsule(text: streak, icon: AppSymbols.streak, tint: colors.workouts),
      if (weekly != null)
        _Capsule(
          text: weekly,
          icon: AppSymbols.calendar,
          tint: colors.exercises,
        ),
    ];
    if (capsules.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: capsules,
    );
  }
}

/// A highlight: the icon carries the tint, the text stays in the primary
/// text colour, since the data colours fail contrast as text.
class _Capsule extends StatelessWidget {
  const new({required this.text, required this.icon, required this.tint});

  final String text;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.label;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: AppColors.tintedSurface(tint),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                color: tint,
                size: MediaQuery.textScalerOf(context).scale(style.fontSize!),
              ),
            ),
            Flexible(child: Text(text, style: style)),
          ],
        ),
      ),
    );
  }
}

/// An exercise's name beside its sets; stacked at the largest text sizes.
class _ExerciseLine extends StatelessWidget {
  const new({
    required this.name,
    required this.sets,
    required this.isLargeText,
  });

  final String name;
  final String sets;
  final bool isLargeText;

  @override
  Widget build(BuildContext context) {
    final nameText = Text(
      name,
      style: AppTextStyles.rowDetail,
      maxLines: isLargeText ? null : 1,
      overflow: isLargeText ? null : TextOverflow.ellipsis,
    );
    final setsText = Text(
      sets,
      style: AppTextStyles.rowDetail.secondary(context),
    );
    if (isLargeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [nameText, setsText],
      );
    }
    return Row(
      spacing: AppSpacing.s,
      children: [
        Expanded(child: nameText),
        setsText,
      ],
    );
  }
}
