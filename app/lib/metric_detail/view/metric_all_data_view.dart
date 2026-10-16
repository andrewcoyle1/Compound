import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:flutter/semantics.dart';
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
    this.onDelete,
    super.key,
  });

  /// Deletes the entry at an index, for a screen whose entries are stored
  /// here (Swift `supportsDeletion`): a swipe, or a screen reader's action.
  /// The row leaves when the data says it has gone, so a failed delete
  /// leaves it in place.
  final void Function(int index)? onDelete;

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
              _deletable(
                context,
                index,
                AppListRow(
                  title: text(index),
                  accessory: AppListRowValue(dates.format(entry.date)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _deletable(BuildContext context, int index, Widget row) {
    final onDelete = this.onDelete;
    if (onDelete == null) return row;
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(entries[index]),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: scheme.error,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: Icon(AppSymbols.delete, color: scheme.onError),
          ),
        ),
      ),
      confirmDismiss: (_) async {
        onDelete(index);
        return false;
      },
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: context.l10n.metricDeleteEntry): () =>
              onDelete(index),
        },
        child: row,
      ),
    );
  }
}
