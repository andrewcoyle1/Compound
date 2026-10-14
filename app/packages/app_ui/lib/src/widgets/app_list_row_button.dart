import 'package:app_ui/app_ui.dart';

/// {@template app_list_row_button}
/// A row that opens something. The whole row is the tap target, and it reads
/// as one button.
/// {@endtemplate}
class AppListRowButton extends StatelessWidget {
  /// {@macro app_list_row_button}
  const new({
    required this.title,
    required this.onPressed,
    this.subtitle,
    this.icon,
    this.tint,
    this.accessory = const AppListRowChevron(),
    super.key,
  });

  /// See [AppListRow.title].
  final String title;

  /// Called when the row is tapped. `null` disables it.
  final VoidCallback? onPressed;

  /// See [AppListRow.subtitle].
  final String? subtitle;

  /// See [AppListRow.icon].
  final IconData? icon;

  /// See [AppListRow.tint].
  final Color? tint;

  /// See [AppListRow.accessory]. A chevron by default.
  final AppListRowAccessory? accessory;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onPressed,
          child: AppListRow(
            title: title,
            subtitle: subtitle,
            icon: icon,
            tint: tint,
            accessory: accessory,
          ),
        ),
      ),
    );
  }
}
