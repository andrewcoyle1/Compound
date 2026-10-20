import 'dart:async';
import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:checkin_repository/checkin_repository.dart' show localMidnight;
import 'package:compound/goal_editing/goal_editing_routes.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/programs.dart';
import 'package:compound/progress/bloc/progress_bloc.dart';
import 'package:compound/progress/bloc/progress_figures.dart';
import 'package:compound/progress/logic/progress_carousel.dart';
import 'package:compound/progress/view/card_charts.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:compound_maths/compound_maths.dart'
    show Macros, comparedAverages, zeroMacros;
import 'package:compound_models/compound_models.dart' show Mesocycle;
import 'package:flutter_bloc/flutter_bloc.dart';

/// The header of the Progress tab (Swift `ProgressCarouselView`): the week
/// against its targets, then today's nutrition, a month's energy balance,
/// this week's training and recent records, a page each, with dots under
/// them. Each page's toggle is the page's own, as Swift keeps it on the
/// presenter for the life of the tab.
class ProgressCarousel extends StatefulWidget {
  const new({required this.state, super.key});

  /// The overview's state.
  final ProgressState state;

  @override
  State<ProgressCarousel> createState() => _ProgressCarouselState();
}

class _ProgressCarouselState extends State<ProgressCarousel> {
  var _showsRemaining = false;
  var _comparesTargets = false;
  var _activeProgram = true;
  RecordKind _recordKind = RecordKind.volume;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AppCarousel(
      height: 380,
      pages: [
        for (final page in [
          NutritionTargetChart(state: state),
          _DailyNutrition(
            state: state,
            showsRemaining: _showsRemaining,
            onChanged: (value) => setState(() => _showsRemaining = value),
          ),
          _EnergyBalance(
            state: state,
            comparesTargets: _comparesTargets,
            onChanged: (value) => setState(() => _comparesTargets = value),
          ),
          _WeeklyWorkouts(
            state: state,
            activeProgram: _activeProgram,
            onChanged: (value) => setState(() => _activeProgram = value),
          ),
          _RecentRecords(
            state: state,
            kind: _recordKind,
            onChanged: (kind) => setState(() => _recordKind = kind),
          ),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: page,
          ),
      ],
    );
  }
}

/// A carousel page: its title, the figures, and the toggle at the foot
/// (Swift `CarouselPage`).
class _Page extends StatelessWidget {
  const new({required this.title, required this.child, this.toggle});

  final String title;
  final Widget child;
  final Widget? toggle;

  @override
  Widget build(BuildContext context) {
    final toggle = this.toggle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.l,
      children: [
        _Title(title),
        Expanded(child: child),
        ?toggle,
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const new(this.title, {this.info});

  final String title;
  final MethodInfo? info;

  @override
  Widget build(BuildContext context) {
    final info = this.info;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        if (info != null) MethodInfoButton(info),
      ],
    );
  }
}

/// A segmented control at a page's foot (Swift `CarouselToggle`).
class _Toggle<T> extends StatelessWidget {
  const new({
    required this.selected,
    required this.options,
    required this.label,
    required this.onChanged,
    this.trailing,
  });

  final T selected;
  final List<T> options;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: AppSpacing.s,
      children: [
        Flexible(
          child: AppSegmentedControl<T>(
            segments: [
              for (final option in options)
                AppSegment(value: option, label: label(option)),
            ],
            selected: selected,
            onChanged: onChanged,
          ),
        ),
        ?trailing,
      ],
    );
  }
}

String _whole(num value, String locale) =>
    AppFormat.number(value, locale: locale);

// MARK: - Weekly targets

/// One of the weekly grid's rows.
enum _TargetRow { calories, protein, carbs, fat }

extension on _TargetRow {
  double of(Macros day) => switch (this) {
    _TargetRow.calories => day.calories,
    _TargetRow.protein => day.proteinGrams,
    _TargetRow.carbs => day.carbGrams,
    _TargetRow.fat => day.fatGrams,
  };

  String title(AppLocalizations l10n) => switch (this) {
    _TargetRow.calories => l10n.nutritionOverviewCalories,
    _TargetRow.protein => l10n.progressProtein,
    _TargetRow.carbs => l10n.nutritionMacroCarbs,
    _TargetRow.fat => l10n.nutritionMacroFat,
  };

  IconData get icon => switch (this) {
    _TargetRow.calories => AppSymbols.calories,
    _TargetRow.protein => AppSymbols.protein,
    _TargetRow.carbs => AppSymbols.carbs,
    _TargetRow.fat => AppSymbols.fat,
  };

  Color colour(AppColors colors) => switch (this) {
    _TargetRow.calories => colors.calories,
    _TargetRow.protein => colors.protein,
    _TargetRow.carbs => colors.carbs,
    _TargetRow.fat => colors.fat,
  };

  String amount(double value, String locale) => this == _TargetRow.calories
      ? AppFormat.kcal(value.round(), locale: locale)
      : AppFormat.grams(value, locale: locale);
}

/// Above this share of the target a cell shows the over-target caret
/// (Swift `TargetCellView.caretThreshold`).
const caretThreshold = 1.1;

/// Whether [value] is far enough over [target] for the caret.
bool showsCaret(double value, double target) =>
    target > 0 && value > target * caretThreshold;

/// This week against the plan's targets (Swift `NutritionTargetChartView`):
/// a bar a day for calories and each macro, filled to what was eaten with
/// a tick at the target, and the selected day's figures, or the week's, in
/// the last column. Without a plan of seven days, nothing is invented.
class NutritionTargetChart extends StatelessWidget {
  const new({required this.state, super.key});

  /// The overview's state.
  final ProgressState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final targets = state.targetWeek;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s,
      children: [
        _Title(l10n.targetChartTitle, info: MethodInfo.macroSplit(l10n)),
        if (targets == null)
          Expanded(
            child: AppEmptyState(
              icon: AppSymbols.meal,
              title: l10n.targetChartNoPlan,
              description: l10n.targetChartNoPlanMessage,
              actionLabel: l10n.targetChartCreatePlan,
              onAction: () {
                context.read<ProgressBloc>().add(
                  const ProgressCreatePlanPressed(),
                );
                openDietPlan(context);
              },
            ),
          )
        else
          // Sized to its content, the key straight under the grid; any
          // height the carousel's taller pages leave goes below.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.m,
                children: [
                  _Grid(state: state, targets: targets),
                  ExcludeSemantics(
                    child: Text(
                      l10n.targetChartKey,
                      style: AppTextStyles.label.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One metric's row: each day's eaten and target, and the figures shown.
typedef _RowFigures = ({
  _TargetRow row,
  List<double> eaten,
  List<double> goal,
  String amount,
  String of,
  String value,
});

/// The grid: a row of day cells per metric with the figures beside them,
/// or, when the figures would take more than a third of the width (large
/// text), above them, so the cells keep the full width and no figure is
/// shrunk or cut.
class _Grid extends StatelessWidget {
  const new({required this.state, required this.targets});

  final ProgressState state;
  final List<Macros> targets;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final logged = state.loggedWeek;
    final days = [for (final key in state.weekDayKeys) localMidnight(key)];
    final selected = state.targetDay;
    final today = (state.now.weekday - state.firstWeekday + 7) % 7;
    final secondary = AppTextStyles.label.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final iconSize = AppIconSize.small.of(context);
    String names(DateTime date) => AppFormat.date(
      date,
      style: AppDateStyle.weekday,
      locale: context.dateLocale,
    );
    String letters(DateTime date) => AppFormat.date(
      date,
      style: AppDateStyle.weekdayInitial,
      locale: context.dateLocale,
    );
    void press(int day) {
      unawaited(AppHaptics.selection());
      context.read<ProgressBloc>().add(ProgressTargetDayPressed(day));
    }

    String cellValue(_TargetRow row, double eaten, double target) {
      final amounts = l10n.targetChartAmountOf(
        row.amount(eaten, locale),
        row.amount(target, locale),
      );
      return target > 0 && eaten > target
          ? l10n.targetChartOverTarget(amounts)
          : amounts;
    }

    final rows = <_RowFigures>[
      for (final row in _TargetRow.values)
        () {
          final eaten = [for (final d in logged) row.of(d)];
          final goal = [for (final d in targets) row.of(d)];
          final summary = selected == null
              ? (
                  eaten: eaten.reduce((a, b) => a + b),
                  goal: goal.reduce((a, b) => a + b),
                )
              : (eaten: eaten[selected], goal: goal[selected]);
          return (
            row: row,
            eaten: eaten,
            goal: goal,
            amount: row.amount(summary.eaten, locale),
            of: l10n.targetChartOf(row.amount(summary.goal, locale)),
            value: cellValue(row, summary.eaten, summary.goal),
          );
        }(),
    ];
    // The figures' width unwrapped: the icon and amount, or the target.
    final figuresWidth = math.max(
      iconSize +
          AppSpacing.xxs +
          _wordWidth(context, [
            for (final r in rows) (r.amount, AppTextStyles.metricSmall),
          ], lines: true),
      _wordWidth(context, [
        for (final r in rows) (r.of, AppTextStyles.label),
      ], lines: true),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = figuresWidth > constraints.maxWidth / 3;
        Widget figures(_RowFigures r) {
          final amount = Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xxs,
            children: [
              Icon(r.row.icon, size: iconSize, color: r.row.colour(colors)),
              Text(r.amount, style: AppTextStyles.metricSmall),
            ],
          );
          return Semantics(
            label: selected == null
                ? l10n.targetChartThisWeek(r.row.title(l10n))
                : '${r.row.title(l10n)}, ${names(days[selected])}',
            value: r.value,
            child: ExcludeSemantics(
              child: stacked
                  ? Wrap(
                      spacing: AppSpacing.s,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        amount,
                        Text(r.of, style: secondary),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        amount,
                        Text(r.of, style: secondary),
                      ],
                    ),
            ),
          );
        }

        Widget cells(_RowFigures r) {
          final most = math
              .max(
                math.max(r.goal.reduce(math.max), r.eaten.reduce(math.max)),
                1,
              )
              .toDouble();
          return Row(
            spacing: AppSpacing.s,
            children: [
              for (var day = 0; day < 7; day++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: day == selected,
                    label: '${names(days[day])}, ${r.row.title(l10n)}',
                    value: cellValue(r.row, r.eaten[day], r.goal[day]),
                    hint: day == selected
                        ? l10n.targetChartShowsWeek
                        : l10n.targetChartShowsDay,
                    child: GestureDetector(
                      onTap: () => press(day),
                      child: ExcludeSemantics(
                        child: _TargetCell(
                          value: r.eaten[day],
                          target: r.goal[day],
                          maximum: most,
                          tint: r.row.colour(colors),
                          selected: day == selected,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }

        final week = Text(
          selected == null ? l10n.targetChartWeek : '',
          style: secondary,
        );
        final weekdays = ExcludeSemantics(
          child: Row(
            spacing: AppSpacing.s,
            children: [
              for (var day = 0; day < 7; day++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => press(day),
                    child: Text(
                      letters(days[day]),
                      textAlign: TextAlign.center,
                      style:
                          (day == selected
                                  ? AppTextStyles.label.semibold
                                  : AppTextStyles.label)
                              .copyWith(
                                color: day == today
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                    ),
                  ),
                ),
              if (!stacked) SizedBox(width: figuresWidth, child: week),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.m,
          children: [
            for (final r in rows)
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xs,
                  children: [figures(r), cells(r)],
                )
              else
                Row(
                  spacing: AppSpacing.s,
                  children: [
                    Expanded(child: cells(r)),
                    SizedBox(width: figuresWidth, child: figures(r)),
                  ],
                ),
            weekdays,
            if (stacked && selected == null) ExcludeSemantics(child: week),
          ],
        );
      },
    );
  }
}

/// One day of one metric (Swift `TargetCellView`): a bar filled to what
/// was eaten, a tick at the target, and a caret when well over it.
class _TargetCell extends StatelessWidget {
  const new({
    required this.value,
    required this.target,
    required this.maximum,
    required this.tint,
    required this.selected,
  });

  final double value;
  final double target;
  final double maximum;
  final Color tint;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1 / 1.2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.s),
          border: selected ? Border.all(color: scheme.primary, width: 2) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: BulletBar(
            value: value,
            maximum: maximum,
            target: target,
            over: showsCaret(value, target),
            direction: Axis.vertical,
            color: tint,
          ),
        ),
      ),
    );
  }
}

// MARK: - Daily nutrition

/// Today's calories on a gauge and the macros on bars, consumed or
/// remaining (Swift `DailyNutritionCard`).
class _DailyNutrition extends StatelessWidget {
  const new({
    required this.state,
    required this.showsRemaining,
    required this.onChanged,
  });

  final ProgressState state;
  final bool showsRemaining;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final eaten = state.todayTotals ?? zeroMacros;
    final target = state.todayTarget;
    final calories = target != null && target.calories > 0
        ? target.calories
        : null;
    final remaining = calories == null
        ? null
        : math.max(calories - eaten.calories, 0).toDouble();
    final fraction = calories == null
        ? 0.0
        : math.min(eaten.calories / calories, 1).toDouble();
    final consumedText = _whole(eaten.calories, locale);
    final remainingText = remaining == null
        ? AppFormat.placeholder
        : _whole(remaining, locale);
    final leading = showsRemaining
        ? (value: consumedText, label: l10n.carouselConsumed)
        : (value: remainingText, label: l10n.carouselRemaining);
    final trailing = (
      value: calories == null
          ? AppFormat.placeholder
          : _whole(calories, locale),
      label: l10n.carouselTarget,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final stats = _wordWidth(context, [
      for (final stat in [leading, trailing]) ...[
        (stat.value, AppTextStyles.metric),
        (stat.label, AppTextStyles.label),
      ],
    ]);
    return _Page(
      title: l10n.carouselDailyNutrition,
      toggle: _Toggle<bool>(
        selected: showsRemaining,
        options: const [false, true],
        label: (remaining) =>
            remaining ? l10n.carouselRemaining : l10n.carouselConsumed,
        onChanged: onChanged,
      ),
      child: Column(
        spacing: AppSpacing.l,
        children: [
          Expanded(
            child: _Trio(
              leading: AppStat(
                alignment: CrossAxisAlignment.center,
                value: leading.value,
                label: leading.label,
              ),
              centre: _CalorieGauge(
                fraction: fraction,
                showsRemaining: showsRemaining,
                value: showsRemaining ? remainingText : consumedText,
                label: showsRemaining
                    ? l10n.carouselRemaining
                    : l10n.carouselConsumed,
                color: colors.calories,
              ),
              trailing: AppStat(
                alignment: CrossAxisAlignment.center,
                value: trailing.value,
                label: trailing.label,
              ),
              rowWidth: 2 * stats + scaler.scale(_CalorieGauge.diameter),
              pairWidth: 2 * stats,
            ),
          ),
          Row(
            spacing: AppSpacing.l,
            children: [
              for (final (title, colour, of) in [
                (
                  l10n.progressProtein,
                  colors.protein,
                  (Macros m) => m.proteinGrams,
                ),
                (l10n.nutritionMacroFat, colors.fat, (Macros m) => m.fatGrams),
                (
                  l10n.nutritionMacroCarbs,
                  colors.carbs,
                  (Macros m) => m.carbGrams,
                ),
              ])
                Expanded(
                  child: _MacroBar(
                    title: title,
                    colour: colour,
                    consumed: of(eaten),
                    target: target == null ? null : of(target),
                    showsRemaining: showsRemaining,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const new({
    required this.title,
    required this.colour,
    required this.consumed,
    required this.target,
    required this.showsRemaining,
  });

  final String title;
  final Color colour;
  final double consumed;
  final double? target;
  final bool showsRemaining;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    final target = this.target;
    final fraction = target == null || target <= 0
        ? 0.0
        : math.min(consumed / target, 1).toDouble();
    final amount = showsRemaining
        ? (target == null ? 0.0 : math.max(target - consumed, 0).toDouble())
        : consumed;
    final figure = target == null
        ? AppFormat.grams(amount, locale: locale)
        : '${_whole(amount, locale)} / '
              '${AppFormat.grams(target, locale: locale)}';
    return Semantics(
      label: title,
      value: figure,
      child: ExcludeSemantics(
        child: Column(
          spacing: AppSpacing.xs,
          children: [
            Text(
              title,
              style: AppTextStyles.label.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            // What is left runs from what was eaten to the end.
            BulletBar(
              from: showsRemaining ? fraction : 0,
              value: showsRemaining ? 1 : fraction,
              thickness: AppChartMark.bulletWidthSmall,
              color: colour,
            ),
            FittedBox(child: Text(figure, style: AppTextStyles.metricSmall)),
          ],
        ),
      ),
    );
  }
}

/// Three quarters of a circle, open at the foot, filled to how far into
/// the day's calories the user is, or the part still to eat.
class _CalorieGauge extends StatelessWidget {
  const new({
    required this.fraction,
    required this.showsRemaining,
    required this.value,
    required this.label,
    required this.color,
  });

  final double fraction;
  final bool showsRemaining;
  final String value;
  final String label;
  final Color color;

  /// Its size at the default text size.
  static const double diameter = 150;

  @override
  Widget build(BuildContext context) {
    return ProgressArc(
      sweep: ArcSweep.gauge,
      from: showsRemaining ? fraction : 0,
      value: showsRemaining ? 1 : fraction,
      color: color,
      diameter: diameter,
      semanticLabel: label,
      semanticValue: value,
      child: Column(
        children: [
          Text(value, style: AppTextStyles.display),
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// How tall [text] is in a record's row style, on one line or wrapped to
/// [width].
double _textHeight(BuildContext context, String text, {double? width}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(AppTextStyles.rowDetail),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: width == null ? 1 : null,
  )..layout(maxWidth: width ?? double.infinity);
  final height = painter.height;
  painter.dispose();
  return height;
}

/// The narrowest [texts] can be set without breaking a word: their longest
/// word at the user's text size.
///
/// With [lines], the widest of them unwrapped instead.
double _wordWidth(
  BuildContext context,
  List<(String, TextStyle)> texts, {
  bool lines = false,
}) {
  final base = DefaultTextStyle.of(context).style;
  var widest = 0.0;
  for (final (text, style) in texts) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: base.merge(style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    widest = math.max(
      widest,
      lines ? painter.maxIntrinsicWidth : painter.minIntrinsicWidth,
    );
    painter.dispose();
  }
  return widest;
}

/// [centre] between [leading] and [trailing] in a row while that is
/// [rowWidth] wide or less, the three at full size with no word broken;
/// else [centre] above the other two, side by side while they fit
/// [pairWidth], else one above the other. Words are never split and text
/// never shrinks: the rings give way to the height left.
class _Trio extends StatelessWidget {
  const new({
    required this.leading,
    required this.centre,
    required this.trailing,
    required this.rowWidth,
    required this.pairWidth,
    this.rowAlignment = CrossAxisAlignment.center,
  });

  final Widget leading;
  final Widget centre;
  final Widget trailing;
  final double rowWidth;
  final double pairWidth;

  /// How the three line up in a row.
  final CrossAxisAlignment rowAlignment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = AppSpacing.s;
      final width = constraints.maxWidth;
      if (rowWidth + 2 * gap <= width) {
        return Row(
          crossAxisAlignment: rowAlignment,
          spacing: gap,
          children: [
            Expanded(child: leading),
            centre,
            Expanded(child: trailing),
          ],
        );
      }
      return Column(
        spacing: AppSpacing.m,
        children: [
          Expanded(child: centre),
          if (pairWidth + gap <= width)
            Expanded(
              child: Row(
                spacing: gap,
                children: [
                  Expanded(child: leading),
                  Expanded(child: trailing),
                ],
              ),
            )
          else ...[
            Expanded(child: leading),
            Expanded(child: trailing),
          ],
        ],
      );
    },
  );
}

// MARK: - Energy balance

/// The last 30 days' intake against the expenditure or the plan's
/// calories, averaged over the logged days (Swift `EnergyBalanceCard`).
class _EnergyBalance extends StatelessWidget {
  const new({
    required this.state,
    required this.comparesTargets,
    required this.onChanged,
  });

  final ProgressState state;
  final bool comparesTargets;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final days = state.energyDays;
    double? comparison(EnergyDay day) =>
        comparesTargets ? day.target : day.expenditure;
    final averages = comparedAverages([
      for (final day in days) (intake: day.intake, comparison: comparison(day)),
    ]);
    final comparisonColour = comparesTargets
        ? scheme.primary
        : colors.expenditure;
    String figure(double Function(({double intake, double comparison})) of) =>
        averages == null ? AppFormat.placeholder : _whole(of(averages), locale);
    Widget sign(String text) => ExcludeSemantics(
      child: Text(
        text,
        style: AppTextStyles.metric.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    return _Page(
      title: l10n.energyBalanceTitle,
      toggle: _Toggle<bool>(
        selected: comparesTargets,
        options: const [false, true],
        label: (targets) =>
            targets ? l10n.carouselTargets : l10n.expenditureTitle,
        onChanged: onChanged,
        trailing: MethodInfoButton(MethodInfo.energyBalance(l10n)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: AppSpacing.xs,
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: StackedBars(
                stacks: [
                  for (final day in days) [day.intake],
                ],
                colors: [colors.calories],
                slots: days.length,
                line: [for (final day in days) comparison(day) ?? 0],
                lineColor: comparisonColour,
              ),
            ),
          ),
          Text(
            l10n.carouselLastDays(energyDayCount),
            style: AppTextStyles.label.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AppStat(
                    alignment: CrossAxisAlignment.center,
                    value: figure((a) => a.intake),
                    label: l10n.progressNutritionHeader,
                  ),
                ),
              ),
              sign('−'),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AppStat(
                    alignment: CrossAxisAlignment.center,
                    value: figure((a) => a.comparison),
                    label: comparesTargets
                        ? l10n.carouselTargets
                        : l10n.expenditureTitle,
                  ),
                ),
              ),
              sign('='),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AppStat(
                    alignment: CrossAxisAlignment.center,
                    value: figure((a) => a.intake - a.comparison),
                    label: l10n.carouselDifference,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// MARK: - Weekly workouts

/// This week's muscles, sets and exercises (Swift `WeeklyWorkoutsCard`).
/// With an active mesocycle, each ring runs to one microcycle of its plan,
/// and the toggle narrows the week to that program's sessions; without
/// one there is nothing to narrow to or aim at, so neither shows.
class _WeeklyWorkouts extends StatelessWidget {
  const new({
    required this.state,
    required this.activeProgram,
    required this.onChanged,
  });

  final ProgressState state;

  /// Whether only the active program's sessions count.
  final bool activeProgram;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final mesocycle = context.select<ProgramsCubit, Mesocycle?>(
      (cubit) => cubit.state.activeMesocycle,
    );
    final tally = state.weekTally(
      mesocycleId: activeProgram ? mesocycle?.id : null,
    );
    final target = mesocycle == null ? null : mesocycleTarget(mesocycle);
    final rings = [
      for (final (value, aim, title, colour, diameter) in [
        (
          tally.muscles,
          target?.muscles,
          l10n.carouselMuscles,
          colors.muscleGroups,
          _Ring.small,
        ),
        (tally.sets, target?.sets, l10n.statSets, colors.workouts, _Ring.large),
        (
          tally.exercises,
          target?.exercises,
          l10n.progressExercises,
          colors.exercises,
          _Ring.small,
        ),
      ])
        _Ring(
          value: value,
          target: aim,
          title: title,
          colour: colour,
          diameter: diameter,
        ),
    ];
    final scaler = MediaQuery.textScalerOf(context);
    // The narrowest each ring's caption goes without breaking a word.
    // The middle one sits at its natural width in a row, unwrapped.
    double words(_Ring ring, [_Ring? other]) => _wordWidth(context, [
      for (final r in [ring, ?other]) ...[
        (r.title, AppTextStyles.rowTitle),
        if (r.target case final aim?)
          (l10n.carouselRingTarget(aim), AppTextStyles.label),
      ],
    ], lines: other == null);
    return _Page(
      title: l10n.carouselWeeklyWorkouts,
      toggle: mesocycle == null
          ? null
          : _Toggle<bool>(
              selected: activeProgram,
              options: const [true, false],
              label: (program) => program
                  ? l10n.carouselActiveProgram
                  : l10n.carouselAllWorkouts,
              onChanged: onChanged,
            ),
      child: _Trio(
        leading: rings[0],
        centre: rings[1],
        trailing: rings[2],
        rowWidth:
            2 * math.max(scaler.scale(_Ring.small), words(rings[0], rings[2])) +
            math.max(scaler.scale(_Ring.large), words(rings[1])),
        pairWidth: 2 * words(rings[0], rings[2]),
        rowAlignment: CrossAxisAlignment.start,
      ),
    );
  }
}

/// A count in a ring filled toward its [target], if any, with what is left
/// and the target itself (Swift `TallyRing`).
class _Ring extends StatelessWidget {
  const new({
    required this.value,
    required this.target,
    required this.title,
    required this.colour,
    required this.diameter,
  });

  final int value;
  final int? target;
  final String title;
  final Color colour;
  final double diameter;

  /// The side rings' size at the default text size.
  static const double small = 92;

  /// The middle ring's.
  static const double large = 136;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final text = _whole(value, locale);
    final target = this.target;
    final secondary = AppTextStyles.label.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: AppSpacing.m,
      children: [
        // Past the target, the ring laps itself. It gives way to the
        // captions when height runs short.
        Flexible(
          child: ProgressArc(
            value: target == null || target <= 0 ? 0 : value / target,
            color: colour,
            diameter: diameter,
            semanticLabel: title,
            semanticValue: target == null
                ? text
                : l10n.progressOfTarget(text, _whole(target, locale)),
            child: Column(
              children: [
                Text(
                  text,
                  style: AppTextStyles.metricLarge.copyWith(color: colour),
                ),
                if (target != null)
                  Text(
                    l10n.carouselLeft(math.max(target - value, 0)),
                    style: secondary,
                  ),
              ],
            ),
          ),
        ),
        ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xxs,
            children: [
              Text(
                title,
                style: AppTextStyles.rowTitle,
                textAlign: TextAlign.center,
              ),
              if (target != null)
                Text(
                  l10n.carouselRingTarget(target),
                  style: secondary,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// MARK: - Recent records

/// Each exercise's best, the most recently set first, as bars against the
/// largest (Swift `RecentRecordsCard`). Weights show in each exercise's
/// own unit, else the profile's.
class _RecentRecords extends StatelessWidget {
  const new({required this.state, required this.kind, required this.onChanged});

  final ProgressState state;
  final RecordKind kind;
  final ValueChanged<RecordKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final records = state.records(kind);
    final top = records.map((r) => r.value).fold<double>(0, math.max);
    String text(ExerciseRecord record) => switch (kind) {
      RecordKind.reps => l10n.repCount(record.value.round()),
      RecordKind.volume || RecordKind.oneRepMax => AppFormat.weight(
        record.value,
        state.unitFor(record.templateId),
        locale: locale,
      ),
    };
    return _Page(
      title: l10n.carouselRecentRecords,
      toggle: _Toggle<RecordKind>(
        selected: kind,
        options: RecordKind.values,
        label: (kind) => switch (kind) {
          RecordKind.volume => l10n.carouselVolume,
          RecordKind.reps => l10n.carouselReps,
          RecordKind.oneRepMax => l10n.carouselOneRepMax,
        },
        onChanged: onChanged,
        trailing: switch (kind) {
          RecordKind.oneRepMax => MethodInfoButton(
            MethodInfo.estimatedOneRepMax(l10n),
          ),
          RecordKind.volume => MethodInfoButton(MethodInfo.tonnage(l10n)),
          RecordKind.reps => null,
        },
      ),
      child: records.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpacing.s,
                children: [
                  Icon(
                    AppSymbols.personalRecord,
                    size: AppIconSize.hero.of(context),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  Text(
                    l10n.carouselNoRecords,
                    style: AppTextStyles.sectionTitle,
                  ),
                  Text(
                    l10n.carouselNoRecordsMessage,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.rowDetail,
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final scaler = MediaQuery.textScalerOf(context);
                final name = scaler.scale(130);
                final figure = math.min(
                  _wordWidth(context, [
                    for (final record in records)
                      (text(record), AppTextStyles.rowDetail),
                  ], lines: true).ceilToDouble(),
                  constraints.maxWidth / 2,
                );
                // The name beside its bar while the name, a bar and the
                // widest figure fit across; else the name goes above.
                final beside =
                    name +
                        scaler.scale(AppSpacing.xxl) +
                        figure +
                        2 * AppSpacing.s <=
                    constraints.maxWidth;
                // The page is a glance at the latest: as many whole rows
                // as its height holds, never a row cut in half.
                double height(ExerciseRecord record) {
                  final measure = math.max(
                    _textHeight(context, text(record), width: figure),
                    scaler.scale(AppChartMark.bulletWidth),
                  );
                  return beside
                      ? math.max(_textHeight(context, record.name), measure)
                      : _textHeight(
                              context,
                              record.name,
                              width: constraints.maxWidth,
                            ) +
                            AppSpacing.xxs +
                            measure;
                }

                var used = -AppSpacing.m;
                final shown = records.takeWhile((record) {
                  used += AppSpacing.m + height(record);
                  return used <= constraints.maxHeight;
                }).toList();
                return SingleChildScrollView(
                  child: Column(
                    spacing: AppSpacing.m,
                    children: [
                      for (final record
                          in shown.isEmpty ? records.take(1) : shown)
                        Semantics(
                          label: record.name,
                          value: text(record),
                          child: ExcludeSemantics(
                            child: _RecordRow(
                              name: record.name,
                              figure: text(record),
                              nameWidth: beside ? name : null,
                              figureWidth: figure,
                              bar: BulletBar(
                                value: record.value,
                                maximum: top,
                                color: colors.personalRecord,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// One record: its name, then its bar and figure, the name beside them
/// when [nameWidth] is given (cut to one line) and above them otherwise
/// (as many lines as it needs).
class _RecordRow extends StatelessWidget {
  const new({
    required this.name,
    required this.figure,
    required this.nameWidth,
    required this.figureWidth,
    required this.bar,
  });

  final String name;
  final String figure;
  final double? nameWidth;
  final double figureWidth;
  final Widget bar;

  @override
  Widget build(BuildContext context) {
    final nameWidth = this.nameWidth;
    final measure = Row(
      spacing: AppSpacing.s,
      children: [
        Expanded(child: bar),
        SizedBox(
          width: figureWidth,
          child: Text(
            figure,
            textAlign: TextAlign.end,
            style: AppTextStyles.rowDetail,
          ),
        ),
      ],
    );
    if (nameWidth == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xxs,
        children: [
          Text(name, style: AppTextStyles.rowDetail),
          measure,
        ],
      );
    }
    return Row(
      spacing: AppSpacing.s,
      children: [
        SizedBox(
          width: nameWidth,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.rowDetail,
          ),
        ),
        Expanded(child: measure),
      ],
    );
  }
}
