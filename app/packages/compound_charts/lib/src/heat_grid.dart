import 'dart:async';
import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/src/chart_callout.dart';
import 'package:flutter/semantics.dart' show SemanticsProperties;

/// Days as shaded squares (Swift QuickCharts' `ContributionChart`,
/// GitHub's contribution graph): each day's level, from 0 (empty) to one
/// less than [levels], is a shade of [color].
///
/// An empty day is the theme's neutral `surfaceContainerHighest`, which
/// recedes on the canvas and on a card in light and dark mode alike. The
/// shades step evenly from [AppChartMark.heatFirstShade] of the way from
/// the surface towards [color] up to [color] itself, so they lighten
/// towards white in light mode and darken towards black in dark: two
/// levels are empty and full, and the faintest of five still stands apart
/// from empty. [HeatGridLegend] is their key.
///
/// The squares draw in when first shown, a wave across the grid fading and
/// growing each into place over [AppMotion.progress]; reduced motion shows
/// them at once.
///
/// A [HeatGrid] is a calendar: a week to a column, its days down the rows
/// from [firstWeekday], back to the week of the earliest of [days] (or as
/// far as fills the width) and scrolled to [today]'s week, the last
/// column. A day still to come has no square. With [showsWeekdays], each
/// row is named by its weekday's initial; with [showsMonths], each month
/// is named over the column it starts in. The squares are about
/// [AppChartMark.heatCell] at the default text size, stretched a little so
/// whole weeks fill the width it is given (which must be bounded), and
/// grow with the text, so the names always fit.
///
/// With [onSelected], pressing and holding a day picks it and follows the
/// finger, with a selection haptic, then picks null on letting go. The
/// [selected] day is ringed, with [callout] floating above the grid over
/// it ([ChartCallout]). With [weekLabel], a screen reader reads each week
/// as one node.
///
/// A [HeatGrid.packed] grid is a card's: the days down each column in
/// turn, filling the space it is given, with no labels or gestures.
class HeatGrid extends StatefulWidget {
  /// A calendar of [days] up to [today].
  const new({
    required this.days,
    required DateTime this.today,
    required this.levels,
    required this.color,
    this.firstWeekday = DateTime.monday,
    this.showsWeekdays = true,
    this.showsMonths = true,
    this.selected,
    this.onSelected,
    this.callout,
    this.weekLabel,
    super.key,
  }) : values = const [],
       rows = DateTime.daysPerWeek;

  /// A card's grid of [values], [rows] to a column.
  const new packed({
    required this.values,
    required this.levels,
    required this.color,
    this.rows = 3,
    super.key,
  }) : days = const {},
       today = null,
       firstWeekday = DateTime.monday,
       showsWeekdays = false,
       showsMonths = false,
       selected = null,
       onSelected = null,
       callout = null,
       weekLabel = null;

  /// Each day's level, keyed by the day at midnight; a day left out is 0.
  final Map<DateTime, int> days;

  /// A packed grid's levels, a day each, oldest first.
  final List<int> values;

  /// How many shades a square can take, counting empty: 2 or more.
  final int levels;

  /// The fullest shade.
  final Color color;

  /// The last day, at midnight; null for a packed grid.
  final DateTime? today;

  /// The week's first day, as an ISO weekday (1 = Monday).
  final int firstWeekday;

  /// How many days go down each column.
  final int rows;

  /// Whether each row is named by its weekday's initial.
  final bool showsWeekdays;

  /// Whether each month is named over the column it starts in.
  final bool showsMonths;

  /// The day ringed, and the callout's.
  final DateTime? selected;

  /// Called with the day under a held finger, and null when let go.
  final ValueChanged<DateTime?>? onSelected;

  /// What the [selected] day holds, shown in a [ChartCallout].
  final Widget? callout;

  /// What a screen reader says for the week starting on the day given.
  final String Function(DateTime weekStart)? weekLabel;

  @override
  State<HeatGrid> createState() => _HeatGridState();
}

/// A square: where it sits and its level.
typedef _Cell = ({int column, int row, int level});

/// The shades of [levels] levels towards [color], empty first: empty is
/// the theme's neutral `surfaceContainerHighest`, and the rest step from
/// the surface towards [color], as GitHub's do from white in light mode and
/// from black in dark.
List<Color> _shades(BuildContext context, int levels, Color color) {
  final scheme = Theme.of(context).colorScheme;
  const first = AppChartMark.heatFirstShade;
  return [
    scheme.surfaceContainerHighest,
    for (var level = 1; level < levels; level++)
      Color.lerp(
        scheme.surface,
        color,
        levels == 2 ? 1 : first + (1 - first) * (level - 1) / (levels - 2),
      )!,
  ];
}

/// Whole days from [from] to [to], whatever daylight saving does between.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

class _HeatGridState extends State<HeatGrid> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Draws in [painter] over [AppMotion.progress], once.
  Widget _revealing(_HeatPainter Function(double reveal) painter) =>
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.progress.durationOf(context),
        builder: (context, reveal, _) =>
            CustomPaint(painter: painter(reveal), size: Size.infinite),
      );

  int _level(int level) => level.clamp(0, widget.levels - 1);

  @override
  Widget build(BuildContext context) {
    assert(widget.levels >= 2, 'A heat grid needs two levels or more.');
    return widget.today == null ? _packed(context) : _calendar(context);
  }

  Widget _packed(BuildContext context) {
    final rows = widget.rows;
    final values = widget.values;
    final columns = math.max(1, (values.length / rows).ceil());
    const gap = AppChartMark.heatGap;
    final shades = _shades(context, widget.levels, widget.color);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = math
            .max(
              0,
              math.min(
                (constraints.maxWidth - gap * (columns - 1)) / columns,
                (constraints.maxHeight - gap * (rows - 1)) / rows,
              ),
            )
            .toDouble();
        return _revealing(
          (reveal) => _HeatPainter(
            cells: [
              for (final (i, level) in values.indexed)
                (column: i ~/ rows, row: i % rows, level: _level(level)),
            ],
            shades: shades,
            rows: rows,
            cell: cell,
            gap: gap,
            firstShown: 0,
            shownColumns: columns,
            reveal: reveal,
          ),
        );
      },
    );
  }

  Widget _calendar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = context.dateLocale;
    final labelStyle = AppTextStyles.label.copyWith(
      color: scheme.onSurfaceVariant,
    );
    // As the labels grow, so a weekday's initial always fits its row.
    final fontSize = labelStyle.fontSize!;
    final scale = textScaler.scale(fontSize) / fontSize;
    DateTime weekStart(DateTime date) => DateTime(
      date.year,
      date.month,
      date.day - (date.weekday - widget.firstWeekday + 7) % 7,
    );
    final today = widget.today!;
    final last = weekStart(today);
    final earliest = widget.days.keys.fold<DateTime>(
      last,
      (a, b) => b.isBefore(a) ? b : a,
    );
    final logged = _daysBetween(weekStart(earliest), last) ~/ 7;
    double widthOf(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final top = widget.showsMonths
        ? textScaler.scale(labelStyle.fontSize! * labelStyle.height!) +
              AppSpacing.xs
        : 0.0;
    final weekdays = [
      for (var row = 0; row < DateTime.daysPerWeek; row++)
        AppFormat.date(
          // 4 January 2021 was a Monday.
          DateTime(2021, 1, 3 + ((widget.firstWeekday - 1 + row) % 7 + 1)),
          style: AppDateStyle.weekdayInitial,
          locale: locale,
        ),
    ];
    final lettersWidth = widget.showsWeekdays
        ? weekdays.map(widthOf).reduce(math.max) + AppSpacing.s
        : 0.0;
    final shades = _shades(context, widget.levels, widget.color);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxWidth - lettersWidth;
        // Whole weeks fill the width, the squares stretched a little from
        // their size to fit, so no column is cut at the edge.
        final fits = math.max(
          1,
          (viewport + AppChartMark.heatGap * scale) ~/
              ((AppChartMark.heatCell + AppChartMark.heatGap) * scale),
        );
        final fill =
            viewport /
            ((fits * (AppChartMark.heatCell + AppChartMark.heatGap) -
                    AppChartMark.heatGap) *
                scale);
        final cell = AppChartMark.heatCell * scale * fill;
        final gap = AppChartMark.heatGap * scale * fill;
        final step = cell + gap;
        // At least as many weeks as fill the width, as GitHub's grid.
        final weeks = math.max(logged + 1, fits);
        final first = DateTime(
          last.year,
          last.month,
          last.day - 7 * (weeks - 1),
        );
        DateTime dayOf(int column, int row) =>
            DateTime(first.year, first.month, first.day + column * 7 + row);
        final cells = <_Cell>[];
        final months = <(int, String)>[];
        for (var column = 0; column < weeks; column++) {
          for (var row = 0; row < DateTime.daysPerWeek; row++) {
            final day = dayOf(column, row);
            if (day.isAfter(today)) continue;
            cells.add((
              column: column,
              row: row,
              level: _level(widget.days[day] ?? 0),
            ));
            if (day.day == 1 && widget.showsMonths) {
              months.add((
                column,
                AppFormat.date(day, style: AppDateStyle.month, locale: locale),
              ));
            }
          }
        }
        final width = weeks * step - gap;
        final height = top + DateTime.daysPerWeek * step - gap;
        final selected = widget.selected;
        final picked = selected == null
            ? null
            : (
                column: _daysBetween(first, selected) ~/ 7,
                row: _daysBetween(first, selected) % 7,
              );
        final weekLabel = widget.weekLabel;

        DateTime? dayAt(Offset position) {
          final column = (position.dx / step).floor();
          final row = ((position.dy - top) / step).floor();
          if (column < 0 || column >= weeks || row < 0 || row > 6) {
            return null;
          }
          final day = dayOf(column, row);
          return day.isAfter(today) ? null : day;
        }

        void pick(Offset position) {
          final day = dayAt(position);
          if (day == widget.selected) return;
          if (day != null) unawaited(AppHaptics.selection());
          widget.onSelected!(day);
        }

        Widget grid = SizedBox(
          width: width,
          height: height,
          child: _revealing(
            (reveal) => _HeatPainter(
              cells: cells,
              shades: shades,
              rows: DateTime.daysPerWeek,
              cell: cell,
              gap: gap,
              top: top,
              firstShown: weeks - fits,
              shownColumns: fits,
              reveal: reveal,
              months: months,
              labelStyle: labelStyle,
              textScaler: textScaler,
              selected: picked,
              ring: scheme.onSurface,
              columnLabels: weekLabel == null
                  ? null
                  : [for (var c = 0; c < weeks; c++) weekLabel(dayOf(c, 0))],
              textDirection: Directionality.of(context),
            ),
          ),
        );
        if (widget.onSelected != null) {
          grid = GestureDetector(
            onLongPressStart: (d) => pick(d.localPosition),
            onLongPressMoveUpdate: (d) => pick(d.localPosition),
            onLongPressEnd: (_) => widget.onSelected!(null),
            child: grid,
          );
        }
        // The scroll view is reversed, so the grid's end sits at the
        // viewport's, less however far it has been scrolled back.
        final offset = _scroll.hasClients ? _scroll.offset : 0.0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showsWeekdays)
                  ExcludeSemantics(
                    child: Padding(
                      padding: EdgeInsets.only(top: top),
                      child: SizedBox(
                        width: lettersWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: gap,
                          children: [
                            for (final w in weekdays)
                              SizedBox(
                                height: cell,
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(w, style: labelStyle),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: grid,
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: ChartCallout(
                anchorX: picked == null
                    ? 0
                    : lettersWidth +
                          viewport -
                          width +
                          offset +
                          picked.column * step +
                          cell / 2,
                child: picked == null ? null : widget.callout,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The key to a [HeatGrid]'s shades: [less], a swatch for each of [levels]
/// from empty to [color], then [more]. The swatches grow with the text. A
/// screen reader skips it, since each day says what it holds.
class HeatGridLegend extends StatelessWidget {
  /// The key to a grid of [levels] shades of [color].
  const new({
    required this.levels,
    required this.color,
    required this.less,
    required this.more,
    super.key,
  });

  /// How many shades the grid has, counting empty.
  final int levels;

  /// The grid's fullest shade.
  final Color color;

  /// What the empty end is called, such as "Less".
  final String less;

  /// What the full end is called, such as "More".
  final String more;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.label.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final side = MediaQuery.textScalerOf(context).scale(AppSpacing.m);
    final corner = Radius.circular(
      AppChartMark.heatCorner * side / AppChartMark.heatCell,
    );
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xs,
        children: [
          Text(less, style: style),
          for (final shade in _shades(context, levels, color))
            SizedBox.square(
              dimension: side,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: shade,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(corner),
                  ),
                ),
              ),
            ),
          Text(more, style: style),
        ],
      ),
    );
  }
}

/// Paints a [HeatGrid]: the month names along the top, then each square
/// as far as it has drawn in, then the ring round the one picked.
class _HeatPainter extends CustomPainter {
  const new({
    required this.cells,
    required this.shades,
    required this.rows,
    required this.cell,
    required this.gap,
    required this.firstShown,
    required this.shownColumns,
    required this.reveal,
    this.top = 0,
    this.months = const [],
    this.labelStyle,
    this.textScaler = TextScaler.noScaling,
    this.selected,
    this.ring,
    this.columnLabels,
    this.textDirection = TextDirection.ltr,
  });

  final List<_Cell> cells;
  final List<Color> shades;
  final int rows;
  final double cell;
  final double gap;

  /// The first column on screen, and how many are, which the draw-in sweeps
  /// across; columns before it are already in place.
  final int firstShown;
  final int shownColumns;

  /// How far the draw-in has got, from 0 to 1.
  final double reveal;

  /// The height of the month names over the squares.
  final double top;
  final List<(int, String)> months;
  final TextStyle? labelStyle;
  final TextScaler textScaler;
  final ({int column, int row})? selected;
  final Color? ring;
  final List<String>? columnLabels;
  final TextDirection textDirection;

  /// The share of the draw-in spent starting the wave across; each square
  /// then takes the rest to grow in.
  static const _stagger = 0.5;

  /// How big a square starts, as a share of its size.
  static const _from = 0.6;

  double get _step => cell + gap;

  Rect _rect(int column, int row) =>
      Rect.fromLTWH(column * _step, top + row * _step, cell, cell);

  /// How far [c] has drawn in, from 0 to 1.
  double _shown(_Cell c) {
    if (reveal >= 1) return 1;
    final along = ((c.column - firstShown) + c.row / rows) / shownColumns;
    final delay = along.clamp(0, 1) * _stagger;
    return AppMotion.standard.curve.transform(
      ((reveal - delay) / (1 - _stagger)).clamp(0, 1).toDouble(),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Months start at least four columns apart, and their short names
    // grow with the squares, so two never meet.
    for (final (column, text) in months) {
      TextPainter(
          text: TextSpan(text: text, style: labelStyle),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )
        ..layout()
        ..paint(canvas, Offset(column * _step, 0))
        ..dispose();
    }
    final corner = AppChartMark.heatCorner * cell / AppChartMark.heatCell;
    for (final c in cells) {
      final t = _shown(c);
      if (t == 0) continue;
      final side = cell * (_from + (1 - _from) * t);
      final shade = shades[c.level];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: _rect(c.column, c.row).center,
            width: side,
            height: side,
          ),
          Radius.circular(corner * side / cell),
        ),
        Paint()..color = shade.withValues(alpha: shade.a * t),
      );
    }
    if (selected case final picked?) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _rect(picked.column, picked.row).inflate(gap / 2),
          Radius.circular(corner + gap / 2),
        ),
        Paint()
          ..color = ring!
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppChartMark.heatRingWidth,
      );
    }
  }

  // A new painter comes only with a new frame of the draw-in or a new
  // grid, so it always repaints.
  @override
  bool shouldRepaint(_HeatPainter oldDelegate) => true;

  @override
  SemanticsBuilderCallback? get semanticsBuilder {
    final labels = columnLabels;
    if (labels == null) return null;
    return (size) => [
      for (final (column, label) in labels.indexed)
        CustomPainterSemantics(
          rect: Rect.fromLTWH(column * _step, top, cell, rows * _step - gap),
          properties: SemanticsProperties(
            label: label,
            textDirection: textDirection,
          ),
        ),
    ];
  }

  @override
  bool shouldRebuildSemantics(_HeatPainter oldDelegate) =>
      oldDelegate.columnLabels != columnLabels;
}
