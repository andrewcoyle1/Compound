import 'package:app_ui/app_ui.dart';

/// {@template app_list_row_toggle}
/// A row with a switch: the platform's own switch, and the whole row toggles
/// it. Reads as one toggle carrying the title.
/// {@endtemplate}
class AppListRowToggle extends StatelessWidget {
  /// {@macro app_list_row_toggle}
  const new({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    super.key,
  });

  /// See [AppListRow.title].
  final String title;

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value. `null` disables the row.
  final ValueChanged<bool>? onChanged;

  /// See [AppListRow.subtitle].
  final String? subtitle;

  /// See [AppListRow.icon].
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return MergeSemantics(
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged(!value),
        child: AppListRow(
          title: title,
          subtitle: subtitle,
          icon: icon,
          accessory: AppListRowCustom(
            Switch.adaptive(value: value, onChanged: onChanged),
          ),
        ),
      ),
    );
  }
}
