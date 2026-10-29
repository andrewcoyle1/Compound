import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/first_weekday.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/logic/meal_day.dart' show dayKeyOf;
import 'package:compound/widgets/calendar/calendar_day_marker.dart';
import 'package:compound/widgets/calendar/calendar_header_cubit.dart';
import 'package:compound/widgets/calendar/calendar_sheet.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_bloc/flutter_bloc.dart';

/// A strip of days to pick from, a week wide, each marked by the host
/// (Swift `CalendarHeaderView`): Training's workouts, Nutrition's calories.
/// It scrolls freely both ways and settles on a day's edge; screen readers
/// move a week at a time with actions, and Return to Today comes back once
/// today is off screen. The days on screen and the events live in the
/// [CalendarHeaderCubit] above it, which the host's calendar button shares
/// to open the month picker ([showCalendar]).
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
  /// The strip's inset from the screen's edges.
  static const double _inset = AppSpacing.s;

  final _controller = ScrollController(initialScrollOffset: -_inset);
  final Key _centre = UniqueKey();

  /// The first day of the week the strip opened on: scroll offset 0 puts
  /// it at the strip's leading edge (less the inset), earlier days before.
  late final DateTime _anchor;

  /// A day's width, set at layout; 0 before the first.
  double _extent = 0;

  /// The day the strip last settled on, which the cubit hears of and
  /// need not bring back into view.
  DateTime? _settledOn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _anchor = _weekStart(context.read<CalendarHeaderCubit>().state.shownDay);
  }

  @override
  void didUpdateWidget(CalendarHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selectedDay;
    // Follow a selection made elsewhere, only when it is off screen, so a
    // tap on a visible day never moves the strip.
    if (selected != null && selected != oldWidget.selectedDay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _show(selected));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The first day of [day]'s week, from the locale's first day.
  DateTime _weekStart(DateTime day) {
    // 0 is Sunday, as in the locale's own calendar.
    final firstDay = firstDayOfWeekIndex(context);
    final offset = (day.weekday % 7 - firstDay + 7) % 7;
    return DateTime(day.year, day.month, day.day - offset);
  }

  /// [day]'s place from the anchor, in days; in UTC, so a clock change
  /// between them doesn't shorten a day.
  int _indexOf(DateTime day) => DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(_anchor.year, _anchor.month, _anchor.day)).inDays;

  DateTime _dayAt(int index) =>
      DateTime(_anchor.year, _anchor.month, _anchor.day + index);

  double _offsetOf(num index) => index * _extent - _inset;

  /// The days from the anchor to the leading edge, fractional mid-scroll.
  double get _leading =>
      ((_controller.hasClients ? _controller.offset : -_inset) + _inset) /
      _extent;

  /// Whether [day] is wholly on screen.
  bool _isShown(DateTime day) {
    final index = _indexOf(day);
    return index >= _leading - 0.01 && index + 1 <= _leading + 7.01;
  }

  /// Brings [day]'s week into view unless [day] is already on screen.
  void _show(DateTime day) {
    if (!mounted || _extent == 0 || _isShown(day)) return;
    _scrollTo(_offsetOf(_indexOf(_weekStart(day))));
  }

  /// Scrolls [weeks] whole weeks back (negative) or on, for screen
  /// readers.
  void _scrollWeeks(int weeks) =>
      _scrollTo(_offsetOf(_leading.round() + 7 * weeks));

  void _scrollTo(double offset) {
    if (!_controller.hasClients) return;
    final duration = AppMotion.standard.durationOf(context);
    if (duration == Duration.zero) {
      _controller.jumpTo(offset);
    } else {
      _controller.animateTo(
        offset,
        duration: duration,
        curve: AppMotion.standard.curve,
      );
    }
  }

  /// Keeps the leading day in place when a day's width changes, as on
  /// rotation.
  void _layOut(double extent) {
    if (extent == _extent) return;
    final leading = _extent == 0 ? null : _leading.round();
    _extent = extent;
    if (leading == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) _controller.jumpTo(_offsetOf(leading));
    });
  }

  bool _settled(ScrollEndNotification notification) {
    if (_extent > 0) {
      final day = _settledOn = _dayAt(_leading.round());
      context.read<CalendarHeaderCubit>().dayShown(day);
    }
    return false;
  }

  Widget _cell(DateTime day) => CalendarDayCell(
    day: day,
    today: widget.today,
    isSelected: day == widget.selectedDay,
    marker: widget.markers[dayKeyOf(day)],
    onPressed: (day) {
      context.read<CalendarHeaderCubit>().dayPressed(day);
      widget.onDaySelected(day);
    },
  );

  /// The days one way from the anchor: [indexOf] maps the list's index to
  /// the day's.
  Widget _days(int Function(int) indexOf, {Key? key}) => SliverFixedExtentList(
    key: key,
    itemExtent: _extent,
    delegate: SliverChildBuilderDelegate(
      (context, index) => _cell(_dayAt(indexOf(index))),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<CalendarHeaderCubit, CalendarHeaderState>(
      listenWhen: (previous, current) =>
          previous.shownDay != current.shownDay &&
          current.shownDay != _settledOn,
      listener: (context, state) => _show(state.shownDay),
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: l10n.calendarPreviousWeek): () =>
              _scrollWeeks(-1),
          CustomSemanticsAction(label: l10n.calendarNextWeek): () =>
              _scrollWeeks(1),
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            _layOut((constraints.maxWidth - 2 * _inset) / 7);
            return Stack(
              children: [
                // Never seen: sizes the strip to a day's height at the
                // reader's text size, which a scroll view can't measure.
                Row(
                  children: [
                    SizedBox(
                      width: _extent,
                      child: ExcludeSemantics(
                        child: Visibility.maintain(
                          visible: false,
                          child: _cell(widget.today),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned.fill(
                  child: NotificationListener<ScrollEndNotification>(
                    onNotification: _settled,
                    child: CustomScrollView(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      center: _centre,
                      physics: _DaySnapPhysics(extent: _extent, inset: _inset),
                      slivers: [
                        _days((index) => -1 - index),
                        _days((index) => index, key: _centre),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _inset),
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => _returnToToday(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _returnToToday() {
    final today = widget.today;
    if (_isShown(today)) return const SizedBox.shrink();
    final ahead = _indexOf(today) > _leading;
    return Align(
      alignment: ahead
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: 1 / 7,
        heightFactor: 1,
        child: _ReturnToToday(
          ahead: ahead,
          onPressed: () =>
              context.read<CalendarHeaderCubit>().returnedToToday(today),
        ),
      ),
    );
  }
}

/// Lands every scroll on a day's edge: wherever a fling would have
/// stopped, rounded to the nearest day.
class _DaySnapPhysics extends ScrollPhysics {
  const new({required this.extent, required this.inset, super.parent});

  final double extent;
  final double inset;

  @override
  _DaySnapPhysics applyTo(ScrollPhysics? ancestor) => _DaySnapPhysics(
    extent: extent,
    inset: inset,
    parent: buildParent(ancestor),
  );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);
    final free = super.createBallisticSimulation(position, velocity);
    final end = free?.x(double.infinity) ?? position.pixels;
    final target = ((end + inset) / extent).roundToDouble() * extent - inset;
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
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
      container: true,
      button: true,
      label: context.l10n.calendarToday,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Material(
          color: scheme.onSurface,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: AppPressable(
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
    final marker = this.marker;
    final isToday = day == today;
    TextStyle weighted(TextStyle style) =>
        isToday ? AppTextStyles.emphasized(style) : style;
    final badge = marker?.badgeCount;
    return Semantics(
      button: true,
      selected: isSelected,
      label: AppFormat.date(
        day,
        style: AppDateStyle.weekdayDayMonthLong,
        locale: context.dateLocale,
      ),
      value: [
        if (isToday) l10n.calendarToday,
        ?marker?.describe(l10n),
      ].join(', '),
      excludeSemantics: true,
      child: AppPressable(
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
                            AppFormat.date(
                              day,
                              style: AppDateStyle.day,
                              locale: context.dateLocale,
                            ),
                            style: isToday
                                ? weighted(AppTextStyles.rowTitle.tabular)
                                      .accent(context)
                                : AppTextStyles.rowTitle.tabular,
                          ),
                          Text(
                            AppFormat.date(
                              day,
                              style: AppDateStyle.weekdayShort,
                              locale: context.dateLocale,
                            ),
                            style: weighted(AppTextStyles.rowDetail)
                                .secondary(context),
                          ),
                          // Always laid out, so today's cell is no taller.
                          DecoratedBox(
                            decoration: ShapeDecoration(
                              shape: const CircleBorder(),
                              color: isToday
                                  ? context.appColors.accentInk
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
    for (final hex in colours) AppColors.fromHex(hex) ?? colors.accentInk,
  ],
  GoalProgressMarker(isOverGoal: true) => [colors.danger],
  // A goal met is done, so the accent, not success green.
  GoalProgressMarker(isGoalMet: true) => [colors.accentInk],
  GoalProgressMarker() => [colors.calories],
  CountMarker() => [colors.accentInk],
};

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
          style: AppTextStyles.label.onAccent(context),
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
