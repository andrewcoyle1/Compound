import 'dart:async';
import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:checkin_repository/checkin_repository.dart' show localMidnight;
import 'package:compound/goal_editing/goal_editing_routes.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/progress/bloc/progress_bloc.dart';
import 'package:compound/progress/bloc/progress_figures.dart';
import 'package:compound/progress/logic/progress_carousel.dart';
import 'package:compound/progress/view/card_charts.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound_maths/compound_maths.dart'
    show Macros, comparedAverages, zeroMacros;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

/// The header of the Progress tab (Swift `ProgressCarouselView`): the week
/// against its targets, then today's nutrition, a month's energy balance,
/// this week's training and recent records, a page each, with dots under
/// them. Each page's toggle is the page's own, as Swift keeps it on the
/// presenter for the life of the tab.
class ProgressCarousel extends StatefulWidget {
  const new({required this.state, super.key});

  /// The overview's state.
  final ProgressState state;

  /// How many pages there are.
  static const pageCount = 5;

  @override
  State<ProgressCarousel> createState() => _ProgressCarouselState();
}

class _ProgressCarouselState extends State<ProgressCarousel> {
  final PageController _controller = PageController();
  var _page = 0;
  var _showsRemaining = false;
  var _comparesTargets = false;
  RecordKind _recordKind = RecordKind.volume;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      spacing: AppSpacing.m,
      children: [
        SizedBox(
          // Every page as tall as the tallest, so the toggles line up.
          height: MediaQuery.textScalerOf(context).scale(380),
          child: PageView(
            controller: _controller,
            onPageChanged: (page) => setState(() => _page = page),
            children: [
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
                  onChanged: (value) =>
                      setState(() => _comparesTargets = value),
                ),
                _WeeklyWorkouts(state: state),
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
          ),
        ),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: AppSpacing.xs,
            children: [
              for (var dot = 0; dot < ProgressCarousel.pageCount; dot++)
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dot == _page
                        ? scheme.onSurfaceVariant
                        : scheme.outlineVariant,
                  ),
                ),
            ],
          ),
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
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            segments: [
              for (final option in options)
                ButtonSegment(value: option, label: Text(label(option))),
            ],
            selected: {selected},
            onSelectionChanged: (selection) => onChanged(selection.single),
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
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.s,
                  children: [
                    Icon(
                      AppSymbols.meal,
                      size: AppIconSize.hero.of(context),
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    Text(
                      l10n.targetChartNoPlan,
                      style: AppTextStyles.sectionTitle,
                    ),
                    Text(
                      l10n.targetChartNoPlanMessage,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.rowDetail,
                    ),
                    FilledButton(
                      onPressed: () {
                        context.read<ProgressBloc>().add(
                          const ProgressCreatePlanPressed(),
                        );
                        openDietPlan(context);
                      },
                      child: Text(l10n.targetChartCreatePlan),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          Expanded(
            child: _Grid(state: state, targets: targets),
          ),
          ExcludeSemantics(
            child: Text(
              l10n.targetChartKey,
              style: AppTextStyles.label.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

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
    final names = DateFormat.EEEE(locale);
    final letters = DateFormat.EEEEE(locale);
    void press(int day) {
      unawaited(HapticFeedback.selectionClick());
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

    return SingleChildScrollView(
      child: Column(
        spacing: AppSpacing.m,
        children: [
          for (final row in _TargetRow.values)
            Row(
              spacing: AppSpacing.s,
              children: [
                ...() {
                  final eaten = [for (final d in logged) row.of(d)];
                  final goal = [for (final d in targets) row.of(d)];
                  final most = math
                      .max(
                        math.max(goal.reduce(math.max), eaten.reduce(math.max)),
                        1,
                      )
                      .toDouble();
                  final summary = selected == null
                      ? (
                          eaten: eaten.reduce((a, b) => a + b),
                          goal: goal.reduce((a, b) => a + b),
                        )
                      : (eaten: eaten[selected], goal: goal[selected]);
                  return [
                    for (var day = 0; day < 7; day++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: day == selected,
                          label:
                              '${names.format(days[day])}, '
                              '${row.title(l10n)}',
                          value: cellValue(row, eaten[day], goal[day]),
                          hint: day == selected
                              ? l10n.targetChartShowsWeek
                              : l10n.targetChartShowsDay,
                          child: GestureDetector(
                            onTap: () => press(day),
                            child: ExcludeSemantics(
                              child: _TargetCell(
                                value: eaten[day],
                                target: goal[day],
                                maximum: most,
                                tint: row.colour(colors),
                                selected: day == selected,
                              ),
                            ),
                          ),
                        ),
                      ),
                    SizedBox(
                      width: MediaQuery.textScalerOf(context).scale(84),
                      child: Semantics(
                        label: selected == null
                            ? l10n.targetChartThisWeek(row.title(l10n))
                            : '${row.title(l10n)}, '
                                  '${names.format(days[selected])}',
                        value: cellValue(row, summary.eaten, summary.goal),
                        child: ExcludeSemantics(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                spacing: AppSpacing.xxs,
                                children: [
                                  Icon(
                                    row.icon,
                                    size: AppIconSize.small.of(context),
                                    color: row.colour(colors),
                                  ),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: Text(
                                        row.amount(summary.eaten, locale),
                                        style: AppTextStyles.metricSmall,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                l10n.targetChartOf(
                                  row.amount(summary.goal, locale),
                                ),
                                style: AppTextStyles.label.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ];
                }(),
              ],
            ),
          ExcludeSemantics(
            child: Row(
              spacing: AppSpacing.s,
              children: [
                for (var day = 0; day < 7; day++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => press(day),
                      child: Text(
                        letters.format(days[day]),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.label.copyWith(
                          fontWeight: day == selected ? FontWeight.bold : null,
                          color: day == today
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  width: MediaQuery.textScalerOf(context).scale(84),
                  child: Text(
                    selected == null ? l10n.targetChartWeek : '',
                    style: AppTextStyles.label.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CellPainter(
                  fill: (value / maximum).clamp(0, 1).toDouble(),
                  tick: (target / maximum).clamp(0, 1).toDouble(),
                  tint: tint,
                  track: scheme.outlineVariant,
                  mark: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (showsCaret(value, target))
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: AppIconSize.small.of(context),
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CellPainter extends CustomPainter {
  new({
    required this.fill,
    required this.tick,
    required this.tint,
    required this.track,
    required this.mark,
  });

  final double fill;
  final double tick;
  final Color tint;
  final Color track;
  final Color mark;

  @override
  void paint(Canvas canvas, Size size) {
    final width = math.max(AppSpacing.xs, size.width * 0.3);
    final top = size.height * 0.12;
    final bottom = size.height * 0.88;
    final x = size.width / 2;
    final bar = Rect.fromLTRB(x - width / 2, top, x + width / 2, bottom);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(bar, Radius.circular(width / 2)),
        Paint()..color = track,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            bar.left,
            bottom - (bottom - top) * fill,
            bar.right,
            bottom,
          ),
          Radius.circular(width / 2),
        ),
        Paint()..color = tint,
      );
    final y = bottom - (bottom - top) * tick;
    canvas.drawLine(
      Offset(bar.left - AppSpacing.xxs, y),
      Offset(bar.right + AppSpacing.xxs, y),
      Paint()
        ..color = mark
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CellPainter old) =>
      old.fill != fill ||
      old.tick != tick ||
      old.tint != tint ||
      old.track != track ||
      old.mark != mark;
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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AppStat(
                    alignment: CrossAxisAlignment.center,
                    value: showsRemaining ? consumedText : remainingText,
                    label: showsRemaining
                        ? l10n.carouselConsumed
                        : l10n.carouselRemaining,
                  ),
                ),
              ),
              _CalorieGauge(
                fraction: fraction,
                showsRemaining: showsRemaining,
                value: showsRemaining ? remainingText : consumedText,
                label: showsRemaining
                    ? l10n.carouselRemaining
                    : l10n.carouselConsumed,
                color: colors.calories,
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AppStat(
                    alignment: CrossAxisAlignment.center,
                    value: calories == null
                        ? AppFormat.placeholder
                        : _whole(calories, locale),
                    label: l10n.carouselTarget,
                  ),
                ),
              ),
            ],
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
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.xs),
              child: SizedBox(
                height: AppSpacing.xs,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: scheme.outlineVariant),
                    ),
                    FractionallySizedBox(
                      alignment: showsRemaining
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      widthFactor: showsRemaining ? 1 - fraction : fraction,
                      heightFactor: 1,
                      child: ColoredBox(color: colour),
                    ),
                  ],
                ),
              ),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      value: value,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 150,
          child: CustomPaint(
            painter: _GaugePainter(
              from: showsRemaining ? fraction : 0,
              to: showsRemaining ? 1 : fraction,
              color: color,
              track: scheme.outlineVariant,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(child: Text(value, style: AppTextStyles.display)),
                  Text(
                    label,
                    style: AppTextStyles.label.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  new({
    required this.from,
    required this.to,
    required this.color,
    required this.track,
  });

  final double from;
  final double to;
  final Color color;
  final Color track;

  static const double _sweep = 1.5 * math.pi;
  static const double _start = 0.75 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(4);
    Paint stroke(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep, false, stroke(track));
    if (to > from) {
      canvas.drawArc(
        rect,
        _start + _sweep * from,
        _sweep * (to - from),
        false,
        stroke(color),
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.from != from ||
      old.to != to ||
      old.color != color ||
      old.track != track;
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
/// The program's targets and the Active Program toggle wait for the
/// programs slice's active mesocycle; without one Swift shows neither.
class _WeeklyWorkouts extends StatelessWidget {
  const new({required this.state});

  final ProgressState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final tally = state.weekTally;
    return _Page(
      title: l10n.carouselWeeklyWorkouts,
      child: Row(
        spacing: AppSpacing.s,
        children: [
          Expanded(
            child: _Ring(
              value: tally.muscles,
              title: l10n.carouselMuscles,
              colour: colors.muscleGroups,
              diameter: 92,
            ),
          ),
          _Ring(
            value: tally.sets,
            title: l10n.statSets,
            colour: colors.workouts,
            diameter: 136,
          ),
          Expanded(
            child: _Ring(
              value: tally.exercises,
              title: l10n.progressExercises,
              colour: colors.exercises,
              diameter: 92,
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const new({
    required this.value,
    required this.title,
    required this.colour,
    required this.diameter,
  });

  final int value;
  final String title;
  final Color colour;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final text = _whole(value, locale);
    return Semantics(
      label: title,
      value: text,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.m,
          children: [
            SizedBox.square(
              dimension: diameter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 8,
                  ),
                ),
                child: Center(
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      child: Text(
                        text,
                        style: AppTextStyles.metricLarge.copyWith(
                          color: colour,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(title, style: AppTextStyles.rowTitle),
          ],
        ),
      ),
    );
  }
}

// MARK: - Recent records

/// Each exercise's best, the most recently set first, as bars against the
/// largest (Swift `RecentRecordsCard`). Weights show in the profile's unit
/// (Swift uses each exercise's own, kept on the device).
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
        state.unit,
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
          : SingleChildScrollView(
              child: Column(
                spacing: AppSpacing.m,
                children: [
                  for (final record in records)
                    Semantics(
                      label: record.name,
                      value: text(record),
                      child: ExcludeSemantics(
                        child: Row(
                          spacing: AppSpacing.s,
                          children: [
                            SizedBox(
                              width: MediaQuery.textScalerOf(context)
                                  .scale(130),
                              child: Text(
                                record.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.rowDetail,
                              ),
                            ),
                            Expanded(
                              child: Row(
                                spacing: AppSpacing.s,
                                children: [
                                  Flexible(
                                    child: FractionallySizedBox(
                                      widthFactor: top > 0
                                          ? math.max(record.value / top, 0.03)
                                          : 0.03,
                                      child: Container(
                                        height: AppSpacing.m,
                                        decoration: BoxDecoration(
                                          color: colors.personalRecord,
                                          borderRadius: BorderRadius.circular(
                                            AppSpacing.m,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    text(record),
                                    style: AppTextStyles.rowDetail,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
