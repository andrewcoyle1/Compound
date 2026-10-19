import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/widgets/number_wheel.dart';

/// The Start Time sheet (`WorkoutSessionStartTimeSheet`): the day and the
/// time, never later than now. It holds the pick until Save; Close leaves
/// the workout as it was. Returns the new start, or `null`.
Future<DateTime?> showSessionStartTimeSheet(
  BuildContext context,
  DateTime start,
) => showModalBottomSheet<DateTime>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _StartTimeSheet(start: start.toLocal()),
);

class _StartTimeSheet extends StatefulWidget {
  const new({required this.start});

  final DateTime start;

  @override
  State<_StartTimeSheet> createState() => _StartTimeSheetState();
}

class _StartTimeSheetState extends State<_StartTimeSheet> {
  late DateTime _start = widget.start;

  void _set(DateTime picked) {
    final now = DateTime.now();
    setState(() => _start = picked.isAfter(now) ? now : picked);
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    _set(
      DateTime(
        picked.year,
        picked.month,
        picked.day,
        _start.hour,
        _start.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (picked == null) return;
    _set(
      DateTime(
        _start.year,
        _start.month,
        _start.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SheetScaffold(
      title: l10n.workoutStartTime,
      onSave: () => Navigator.of(context).pop(_start),
      child: AppSection(
        header: l10n.sessionStartedAt,
        footer: l10n.sessionStartTimeFooter,
        children: [
          AppListRowButton(
            title: l10n.sessionDate,
            accessory: AppListRowValue(
              AppFormat.date(
                _start,
                style: AppDateStyle.long,
                locale: context.dateLocale,
              ),
            ),
            onPressed: _pickDay,
          ),
          AppListRowButton(
            title: l10n.sessionTime,
            accessory: AppListRowValue(
              AppFormat.time(
                _start,
                use24HourFormat: context.use24HourFormat,
                locale: context.dateLocale,
              ),
            ),
            onPressed: _pickTime,
          ),
        ],
      ),
    );
  }
}

/// The Duration sheet (`WorkoutSessionDurationSheet`): hours and minutes
/// wheels opening on [hours] and [minutes]. Returns the pick, or `null`
/// when closed.
Future<(int, int)?> showSessionDurationSheet(
  BuildContext context, {
  required int hours,
  required int minutes,
}) => showModalBottomSheet<(int, int)>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _DurationSheet(hours: hours, minutes: minutes),
);

class _DurationSheet extends StatefulWidget {
  const new({required this.hours, required this.minutes});

  final int hours;
  final int minutes;

  @override
  State<_DurationSheet> createState() => _DurationSheetState();
}

class _DurationSheetState extends State<_DurationSheet> {
  late int _hours = widget.hours.clamp(0, 12);
  late int _minutes = widget.minutes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final height = MediaQuery.textScalerOf(context).scale(32) * 5;
    return _SheetScaffold(
      title: l10n.statDuration,
      onSave: () => Navigator.of(context).pop((_hours, _minutes)),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: NumberWheel(
                label: l10n.sessionHours,
                values: [for (var hour = 0; hour < 13; hour++) hour],
                selected: _hours,
                itemLabel: l10n.sessionHoursValue,
                onChanged: (hours) => setState(() => _hours = hours),
              ),
            ),
            Expanded(
              child: NumberWheel(
                label: l10n.timerDurationMinutes,
                values: [for (var minute = 0; minute < 60; minute++) minute],
                selected: _minutes,
                itemLabel: l10n.timerDurationMinutesValue,
                onChanged: (minutes) => setState(() => _minutes = minutes),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A title between Close and Save, over [child].
class _SheetScaffold extends StatelessWidget {
  const new({required this.title, required this.onSave, required this.child});

  final String title;
  final VoidCallback onSave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.l,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(AppSymbols.close),
                tooltip: l10n.socialClose,
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              IconButton(
                icon: const Icon(AppSymbols.selected),
                tooltip: l10n.trackerSave,
                onPressed: onSave,
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}
