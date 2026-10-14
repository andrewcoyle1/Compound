import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:intl/intl.dart' show DateFormat;

/// A week of days to pick from, each ringed with its calories against the
/// day's goal (Swift `CalendarHeaderView` and `CalendarDayCell`). Swiping
/// shows the week before or after; screen readers get the same as actions.
class CalendarStrip extends StatefulWidget {
  const new({
    required this.selectedDay,
    required this.today,
    required this.markers,
    required this.onDaySelected,
    super.key,
  });

  /// The day shown below, at local midnight.
  final DateTime selectedDay;

  /// Today, at local midnight.
  final DateTime today;

  /// Each logged day's mark, by day key.
  final Map<String, CalorieMarker> markers;

  /// Called with the day tapped.
  final ValueChanged<DateTime> onDaySelected;

  @override
  State<CalendarStrip> createState() => _CalendarStripState();
}

class _CalendarStripState extends State<CalendarStrip> {
  /// A day in the week on screen.
  late DateTime _shownDay = widget.selectedDay;

  @override
  void didUpdateWidget(CalendarStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDay != oldWidget.selectedDay) {
      _shownDay = widget.selectedDay;
    }
  }

  void _moveWeeks(int weeks) => setState(
    () => _shownDay = DateTime(
      _shownDay.year,
      _shownDay.month,
      _shownDay.day + 7 * weeks,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 0 is Sunday, as in the locale's own calendar.
    final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final offset = (_shownDay.weekday % 7 - firstDay + 7) % 7;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.nutritionCalendarPreviousWeek): () =>
            _moveWeeks(-1),
        CustomSemanticsAction(label: l10n.nutritionCalendarNextWeek): () =>
            _moveWeeks(1),
      },
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity == 0) return;
          // A swipe towards the end of the line shows the week before.
          _moveWeeks((velocity > 0) != rtl ? -1 : 1);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _DayCell(
                    day: DateTime(
                      _shownDay.year,
                      _shownDay.month,
                      _shownDay.day - offset + i,
                    ),
                    today: widget.today,
                    selectedDay: widget.selectedDay,
                    markers: widget.markers,
                    onPressed: widget.onDaySelected,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const new({
    required this.day,
    required this.today,
    required this.selectedDay,
    required this.markers,
    required this.onPressed,
  });

  final DateTime day;
  final DateTime today;
  final DateTime selectedDay;
  final Map<String, CalorieMarker> markers;
  final ValueChanged<DateTime> onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final marker = markers[dayKeyOf(day)];
    final isToday = day == today;
    final isSelected = day == selectedDay;
    final weight = isToday ? FontWeight.w600 : FontWeight.w400;
    return Semantics(
      button: true,
      selected: isSelected,
      label: DateFormat.MMMMEEEEd(locale).format(day),
      value: [
        if (isToday) l10n.nutritionToday,
        ?_describe(marker, l10n),
      ].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onPressed(day),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: CustomPaint(
            painter: _DayRingPainter(
              marker: marker,
              isSelected: isSelected,
              fill: scheme.surfaceContainerHighest,
              progress: switch (marker) {
                null => null,
                CalorieMarker(isOverGoal: true) => colors.danger.withValues(
                  alpha: 0.5,
                ),
                CalorieMarker(isGoalMet: true) => colors.success.withValues(
                  alpha: 0.5,
                ),
                CalorieMarker(goal: _?) => colors.calories,
                CalorieMarker() => scheme.primary,
              },
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  spacing: AppSpacing.xxs,
                  children: [
                    Text(
                      DateFormat.d(locale).format(day),
                      style: AppTextStyles.rowTitle.copyWith(
                        fontWeight: weight,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      DateFormat.E(locale).format(day),
                      style: AppTextStyles.rowDetail.copyWith(
                        fontWeight: weight,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    // Always laid out, so today's cell is no taller.
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: const CircleBorder(),
                        color: isToday ? scheme.primary : Colors.transparent,
                      ),
                      child: const SizedBox.square(dimension: AppSpacing.xs),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// What a screen reader says the day holds, or null for nothing.
  static String? _describe(CalorieMarker? marker, AppLocalizations l10n) {
    if (marker == null || marker.isEmpty) return null;
    final goal = marker.goal;
    if (goal == null) return l10n.nutritionCalendarLogged;
    return [
      l10n.nutritionCalendarProgress(AppFormat.percent(marker.calories / goal)),
      if (marker.isOverGoal)
        l10n.nutritionCalendarOverGoal
      else if (marker.isGoalMet)
        l10n.nutritionCalendarGoalMet,
    ].join(', ');
  }
}

/// The capsule behind a day: a soft fill when selected, otherwise a track,
/// with the marker's share of it stroked on top, dashed once over goal.
class _DayRingPainter extends CustomPainter {
  new({
    required this.marker,
    required this.isSelected,
    required this.fill,
    required this.progress,
  });

  final CalorieMarker? marker;
  final bool isSelected;
  final Color fill;
  final Color? progress;

  static const double _width = AppSpacing.xxs;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_width / 2);
    final capsule = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.shortestSide / 2),
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width
      ..strokeCap = StrokeCap.round;
    if (isSelected) {
      canvas.drawRRect(capsule, Paint()..color = fill);
    } else {
      canvas.drawRRect(capsule, stroke..color = fill);
    }
    final marker = this.marker;
    final progress = this.progress;
    if (marker == null || progress == null || marker.isEmpty) return;
    final outline = (Path()..addRRect(capsule)).computeMetrics().first;
    final end = outline.length * marker.fraction;
    final dash = marker.isOverGoal ? _width * 1.5 : end;
    for (var start = 0.0; start < end; start += dash * 2) {
      canvas.drawPath(
        outline.extractPath(start, (start + dash).clamp(0, end)),
        stroke..color = progress,
      );
    }
  }

  @override
  bool shouldRepaint(_DayRingPainter oldDelegate) =>
      oldDelegate.marker != marker ||
      oldDelegate.isSelected != isSelected ||
      oldDelegate.fill != fill ||
      oldDelegate.progress != progress;
}
