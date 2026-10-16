import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/logic/meal_day.dart' show dayKeyOf;
import 'package:compound/widgets/calendar/calendar_day_marker.dart';
import 'package:compound/widgets/calendar/calendar_header_cubit.dart';
import 'package:compound/widgets/calendar/calendar_sheet.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

/// A week of days to pick from, each marked by the host (Swift
/// `CalendarHeaderView`): Training's workouts, Nutrition's calories. Swiping
/// shows the week before or after, screen readers get the same as actions,
/// and Return to Today comes back once today is off screen. The week and
/// the events live in the [CalendarHeaderCubit] above it, which the host's
/// calendar button shares to open the month picker ([showCalendar]).
class CalendarHeader extends StatefulWidget {
  const new({
    required this.today,
    required this.markers,
    required this.onDaySelected,
    this.selectedDay,
    super.key,
  });

  /// Today, at local midnight.
  final DateTime today;

  /// Each marked day's marker, by day key.
  final Map<String, CalendarDayMarker> markers;

  /// Called with the day tapped.
  final ValueChanged<DateTime> onDaySelected;

  /// The day shown as selected, or null on a screen without a selection
  /// (Swift `showsSelection: false`).
  final DateTime? selectedDay;

  /// Opens the month picker over the host and hands a picked day to
  /// [onDaySelected] once it has closed, so a push it starts is not swept
  /// away with the sheet (Swift `CalendarHeaderPresenter
  /// .showLargeCalendar`).
  static Future<void> showCalendar(
    BuildContext context, {
    required DateTime today,
    required Map<String, CalendarDayMarker> markers,
    required ValueChanged<DateTime> onDaySelected,
    DateTime? selectedDay,
  }) async {
    final cubit = context.read<CalendarHeaderCubit>()..largeCalendarOpened();
    final picked = await CalendarSheet.show(
      context,
      today: today,
      markers: markers,
      selectedDay: selectedDay,
    );
    cubit.largeCalendarClosed(picked);
    if (picked != null) onDaySelected(picked);
  }

  @override
  State<CalendarHeader> createState() => _CalendarHeaderState();
}

class _CalendarHeaderState extends State<CalendarHeader> {
  @override
  void didUpdateWidget(CalendarHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selectedDay;
    final cubit = context.read<CalendarHeaderCubit>();
    // Follow a selection made elsewhere, only when it is off screen, so a
    // tap on a visible day never moves the strip.
    if (selected != null &&
        selected != oldWidget.selectedDay &&
        !_week(cubit.state.shownDay).contains(selected)) {
      cubit.dayShown(selected);
    }
  }

  /// The seven days of [shownDay]'s week, from the locale's first day.
  List<DateTime> _week(DateTime shownDay) {
    // 0 is Sunday, as in the locale's own calendar.
    final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final offset = (shownDay.weekday % 7 - firstDay + 7) % 7;
    return [
      for (var i = 0; i < 7; i++)
        DateTime(shownDay.year, shownDay.month, shownDay.day - offset + i),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CalendarHeaderCubit>();
    final shownDay = context.select<CalendarHeaderCubit, DateTime>(
      (cubit) => cubit.state.shownDay,
    );
    final week = _week(shownDay);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final todayAhead = widget.today.isAfter(week.last);
    final todayVisible = week.contains(widget.today);
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.calendarPreviousWeek): () =>
            cubit.weekMoved(-1),
        CustomSemanticsAction(label: l10n.calendarNextWeek): () =>
            cubit.weekMoved(1),
      },
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity == 0) return;
          // A swipe towards the end of the line shows the week before.
          cubit.weekMoved((velocity > 0) != rtl ? -1 : 1);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
          child: Stack(
            children: [
              Row(
                children: [
                  for (final day in week)
                    Expanded(
                      child: CalendarDayCell(
                        day: day,
                        today: widget.today,
                        isSelected: day == widget.selectedDay,
                        marker: widget.markers[dayKeyOf(day)],
                        onPressed: (day) {
                          cubit.dayPressed(day);
                          widget.onDaySelected(day);
                        },
                      ),
                    ),
                ],
              ),
              if (!todayVisible)
                Positioned.fill(
                  child: Align(
                    alignment: todayAhead
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: 1 / 7,
                      heightFactor: 1,
                      child: _ReturnToToday(
                        ahead: todayAhead,
                        onPressed: () => cubit.returnedToToday(widget.today),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The opaque capsule over the strip's edge that brings today back, its
/// chevron pointing the way to it.
class _ReturnToToday extends StatelessWidget {
  const new({required this.ahead, required this.onPressed});

  final bool ahead;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: context.l10n.calendarToday,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Material(
          color: scheme.onSurface,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Icon(
                ahead ? AppSymbols.next : AppSymbols.previous,
                color: scheme.surface,
                size: AppIconSize.medium.of(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One day: its number, short weekday and today's dot, inside a capsule
/// that carries the day's marker (Swift `CalendarDayCell`). Shared by the
/// strip and the month picker.
class CalendarDayCell extends StatelessWidget {
  const new({
    required this.day,
    required this.today,
    required this.isSelected,
    required this.marker,
    required this.onPressed,
    super.key,
  });

  final DateTime day;
  final DateTime today;
  final bool isSelected;
  final CalendarDayMarker? marker;
  final ValueChanged<DateTime> onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final marker = this.marker;
    final isToday = day == today;
    final weight = isToday ? FontWeight.w600 : FontWeight.w400;
    final badge = marker?.badgeCount;
    return Semantics(
      button: true,
      selected: isSelected,
      label: DateFormat.MMMMEEEEd(locale).format(day),
      value: [
        if (isToday) l10n.calendarToday,
        ?marker?.describe(l10n),
      ].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onPressed(day),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: CustomPaint(
            painter: CalendarRingPainter(
              marker: marker,
              isSelected: isSelected,
              fill: scheme.surfaceContainerHighest,
              colours: ringColours(marker, scheme, colors),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        spacing: AppSpacing.xxs,
                        children: [
                          Text(
                            DateFormat.d(locale).format(day),
                            style: AppTextStyles.rowTitle.copyWith(
                              fontWeight: weight,
                              color: isToday ? scheme.primary : null,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
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
                              color: isToday
                                  ? scheme.primary
                                  : Colors.transparent,
                            ),
                            child: const SizedBox.square(
                              dimension: AppSpacing.xs,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (badge != null)
                  PositionedDirectional(top: 0, end: 0, child: _Badge(badge)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The strokes' colours: one per workout for sessions, in its mesocycle's
/// colour or the accent; otherwise the one the marker's progress earns.
List<Color> ringColours(
  CalendarDayMarker? marker,
  ColorScheme scheme,
  AppColors colors,
) => switch (marker) {
  null => const [],
  SessionsMarker(:final colours) => [
    for (final hex in colours) parseHexColour(hex) ?? scheme.primary,
  ],
  GoalProgressMarker(isOverGoal: true) => [
    colors.danger.withValues(alpha: 0.5),
  ],
  GoalProgressMarker(isGoalMet: true) => [
    colors.success.withValues(alpha: 0.5),
  ],
  GoalProgressMarker() => [colors.calories],
  CountMarker() => [scheme.primary],
};

/// `#RRGGBB` as a colour, or null when it is not one.
Color? parseHexColour(String? hex) {
  if (hex == null) return null;
  final digits = hex.startsWith('#') ? hex.substring(1) : hex;
  if (digits.length != 6) return null;
  final value = int.tryParse(digits, radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

class _Badge extends StatelessWidget {
  const new(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: scheme.primary,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
        child: Text(
          count > 9 ? '9+' : '$count',
          style: AppTextStyles.label.copyWith(color: scheme.onPrimary),
        ),
      ),
    );
  }
}

/// The capsule behind a day: a soft fill when selected, otherwise a track
/// (none under workouts), with the marker stroked on top from the top
/// centre clockwise: one stroke per workout with a gap between, or the
/// share of a goal, dashed once over it.
class CalendarRingPainter extends CustomPainter {
  new({
    required this.marker,
    required this.isSelected,
    required this.fill,
    required this.colours,
  });

  final CalendarDayMarker? marker;
  final bool isSelected;
  final Color fill;
  final List<Color> colours;

  static const double _width = AppSpacing.xxs;
  static const _quarter = 1.5707963267948966;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_width / 2);
    final radius = rect.shortestSide / 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width
      ..strokeCap = StrokeCap.round;
    final capsule = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final marker = this.marker;
    if (isSelected) {
      canvas.drawRRect(capsule, Paint()..color = fill);
    } else if (marker is! SessionsMarker) {
      canvas.drawRRect(capsule, stroke..color = fill);
    }
    if (marker == null || marker.isEmpty || colours.isEmpty) return;
    final outline = outlineOf(rect, radius).computeMetrics().first;
    final length = outline.length;
    if (marker is SessionsMarker) {
      final count = colours.length;
      final gap = count > 1 ? AppSpacing.xs : 0.0;
      final segment = (length - gap * count) / count;
      stroke.strokeCap = count > 1 ? StrokeCap.butt : StrokeCap.round;
      for (var i = 0; i < count; i++) {
        final start = i * (segment + gap);
        canvas.drawPath(
          outline.extractPath(start, start + segment),
          stroke..color = colours[i],
        );
      }
      return;
    }
    final end = length * marker.fraction;
    final dash = marker.ringIsDashed ? _width * 1.5 : end;
    for (var start = 0.0; start < end; start += dash * 2) {
      canvas.drawPath(
        outline.extractPath(start, (start + dash).clamp(0, end)),
        stroke..color = colours.first,
      );
    }
  }

  /// A capsule's outline in [rect], from the top centre, clockwise.
  static Path outlineOf(Rect rect, double radius) {
    final path = Path()..moveTo(rect.center.dx, rect.top);
    if (rect.width <= rect.height) {
      final top = Rect.fromCircle(
        center: Offset(rect.center.dx, rect.top + radius),
        radius: radius,
      );
      final bottom = Rect.fromCircle(
        center: Offset(rect.center.dx, rect.bottom - radius),
        radius: radius,
      );
      return path
        ..arcTo(top, -_quarter, _quarter, false)
        ..lineTo(rect.right, rect.bottom - radius)
        ..arcTo(bottom, 0, 2 * _quarter, false)
        ..lineTo(rect.left, rect.top + radius)
        ..arcTo(top, 2 * _quarter, _quarter, false);
    }
    final right = Rect.fromCircle(
      center: Offset(rect.right - radius, rect.center.dy),
      radius: radius,
    );
    final left = Rect.fromCircle(
      center: Offset(rect.left + radius, rect.center.dy),
      radius: radius,
    );
    return path
      ..lineTo(rect.right - radius, rect.top)
      ..arcTo(right, -_quarter, 2 * _quarter, false)
      ..lineTo(rect.left + radius, rect.bottom)
      ..arcTo(left, _quarter, 2 * _quarter, false)
      ..lineTo(rect.center.dx, rect.top);
  }

  @override
  bool shouldRepaint(CalendarRingPainter oldDelegate) =>
      oldDelegate.marker != marker ||
      oldDelegate.isSelected != isSelected ||
      oldDelegate.fill != fill ||
      !listEquals(oldDelegate.colours, colours);
}
