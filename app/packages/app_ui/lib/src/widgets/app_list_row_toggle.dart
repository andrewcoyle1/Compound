import 'package:app_ui/app_ui.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

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
          // The row is the tap target, so the switch takes no height of its
          // own: it sits in a line of text and paints into the row's
          // padding, and the row keeps a list row's height.
          accessory: AppListRowCustom(
            SizedBox(
              height: MediaQuery.textScalerOf(context)
                  .scale(AppTextStyles.rowTitle.fontSize!),
              child: OverflowBox(
                maxHeight: double.infinity,
                fit: OverflowBoxFit.deferToChild,
                child: Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
