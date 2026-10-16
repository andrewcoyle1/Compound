import 'package:app_ui/app_ui.dart';

/// {@template app_selectable_row}
/// One option in a choice list: the whole row is a button, a check shows the
/// choice, and the row is announced as selected.
/// {@endtemplate}
class AppSelectableRow extends StatelessWidget {
  /// {@macro app_selectable_row}
  const new({
    required this.title,
    required this.selected,
    required this.onPressed,
    this.subtitle,
    super.key,
  });

  /// See [AppListRow.title].
  final String title;

  /// Whether this is the chosen option.
  final bool selected;

  /// Called when the row is tapped.
  final VoidCallback? onPressed;

  /// Explains the option. Never cut short.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    // One node with its own tap, not MergeSemantics: a merged row added
    // while its list was covered broke the semantics tree when the route
    // above popped (Flutter 3.47, `_buildSemanticsSubtree`; #141).
    return Semantics(
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: title,
      value: subtitle,
      onTap: onPressed,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        child: AppListRow(
          title: title,
          subtitle: subtitle,
          accessory: AppListRowCheckmark(selected: selected),
        ),
      ),
    );
  }
}
