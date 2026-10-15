import 'package:app_ui/app_ui.dart';
import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:intl/intl.dart' show DateFormat;

/// Every entry of a metric, as given (newest first), like Health's "All
/// Recorded Data" (Swift `MetricAllDataView`): the value on the leading
/// edge and its date on the trailing edge, in one section headed with the
/// metric's name.
class MetricAllDataView extends StatelessWidget {
  const new({
    required this.title,
    required this.unit,
    required this.entries,
    this.format,
    this.valueText,
    super.key,
  });

  /// How each value is written, when not as a number and [unit]; Energy
  /// Balance writes "350 deficit".
  final String Function(double value)? format;

  /// The metric's name, the section's header.
  final String title;

  /// The unit symbol every value is shown with.
  final String unit;

  /// The entries, in [unit], in the order shown.
  final List<MetricPoint> entries;

  /// The text for the entry at an index, for an entry that says more than
  /// its value (a workout's sets and volume); by default its value and
  /// [unit].
  final String Function(int index)? valueText;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dates = DateFormat.yMMMd(locale);
    final format = this.format;
    final text =
        valueText ??
        (index) => format != null
            ? format(entries[index].value)
            : [
                AppFormat.number(
                  entries[index].value,
                  maxFractionDigits: 1,
                  locale: locale,
                ),
                if (unit.isNotEmpty) unit,
              ].join(' ');
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        // ponytail: one Column of rows, built eagerly; fine for years of
        // daily weigh-ins, switch to a lazy list if a metric has far more.
        AppSection(
          header: title,
          children: [
            for (final (index, entry) in entries.indexed)
              AppListRow(
                title: text(index),
                accessory: AppListRowValue(dates.format(entry.date)),
              ),
          ],
        ),
      ],
    );
  }
}
