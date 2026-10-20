import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/first_weekday.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/logic/meal_day.dart' show dayKeyOf;
import 'package:compound/widgets/calendar/calendar_day_marker.dart';
import 'package:compound/widgets/calendar/calendar_header.dart';

/// The month picker behind the calendar header (Swift `CalendarView`):
/// eighteen months back to six ahead, each a titled grid of the header's
/// day cells with the same markers, opening on the selected day's month.
/// Today scrolls to this month; picking a day closes the sheet with it.
class CalendarSheet extends StatefulWidget {
  const new({
    required this.today,
    required this.markers,
    this.selectedDay,
    super.key,
  });

  /// How many months before and after today's are offered.
  static const monthsBack = 18;
  static const monthsAhead = 6;

  final DateTime today;
  final Map<String, CalendarDayMarker> markers;
  final DateTime? selectedDay;

  /// Shows the picker; the day picked, or null when it was closed.
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime today,
    required Map<String, CalendarDayMarker> markers,
    DateTime? selectedDay,
  }) => showAppSheet<DateTime>(
    context: context,
    size: AppSheetSize.full,
    builder: (_) =>
        CalendarSheet(today: today, markers: markers, selectedDay: selectedDay),
  );

  /// The first of each month offered, oldest first.
  static List<DateTime> monthsAround(DateTime today) => [
    for (var i = -monthsBack; i <= monthsAhead; i++)
      DateTime(today.year, today.month + i),
  ];

  @override
  State<CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<CalendarSheet> {
  late final List<DateTime> _months = CalendarSheet.monthsAround(widget.today);
  late final Map<DateTime, GlobalKey> _keys = {
    for (final month in _months) month: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    final initial = widget.selectedDay ?? widget.today;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollTo(DateTime(initial.year, initial.month), animate: false),
    );
  }

  void _scrollTo(DateTime month, {required bool animate}) {
    final target = _keys[month]?.currentContext;
    if (target == null || !mounted) return;
    Scrollable.ensureVisible(
      target,
      duration: animate
          ? AppMotion.standard.durationOf(context)
          : Duration.zero,
      curve: AppMotion.standard.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 0 is Sunday, as in the locale's own calendar.
    final firstDay = firstDayOfWeekIndex(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
          child: Row(
            children: [
              AppToolbarButton.close(
                semanticLabel: MaterialLocalizations.of(context)
                    .closeButtonTooltip,
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.calendarTitle,
                    style: AppTextStyles.sectionTitle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              AppTextButton(
                label: l10n.calendarToday,
                onPressed: () => _scrollTo(
                  DateTime(widget.today.year, widget.today.month),
                  animate: true,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final month in _months)
                  _Month(
                    key: _keys[month],
                    month: month,
                    title: AppFormat.date(
                      month,
                      style: AppDateStyle.monthYear,
                      locale: context.dateLocale,
                    ),
                    leading: (month.weekday % 7 - firstDay + 7) % 7,
                    today: widget.today,
                    selectedDay: widget.selectedDay,
                    markers: widget.markers,
                    onPressed: (day) => Navigator.of(context).pop(day),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Month extends StatelessWidget {
  const new({
    required this.month,
    required this.title,
    required this.leading,
    required this.today,
    required this.selectedDay,
    required this.markers,
    required this.onPressed,
    super.key,
  });

  final DateTime month;
  final String title;

  /// Empty cells before the 1st, so it falls under its weekday.
  final int leading;
  final DateTime today;
  final DateTime? selectedDay;
  final Map<String, CalendarDayMarker> markers;
  final ValueChanged<DateTime> onPressed;

  @override
  Widget build(BuildContext context) {
    final length = DateTime(month.year, month.month + 1, 0).day;
    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= length; d++)
        _cell(DateTime(month.year, month.month, d)),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.s,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: AppTextStyles.sectionTitle),
          ),
          for (var row = 0; row < cells.length; row += 7)
            Row(
              children: [
                for (final cell in cells.sublist(row, row + 7))
                  Expanded(child: cell),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(DateTime day) => CalendarDayCell(
    day: day,
    today: today,
    isSelected: day == selectedDay,
    marker: markers[dayKeyOf(day)],
    onPressed: onPressed,
  );
}
