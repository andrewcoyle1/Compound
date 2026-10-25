import 'package:app_ui/app_ui.dart';

/// {@template app_selectable_row}
/// One option in a choice list: the whole row is a button, a check shows the
/// choice, and the row is announced as selected.
///
/// [tile] makes it a card of its own, for a question that is the whole
/// screen (onboarding): put the options in an `AppSection(grouped: false)`.
/// The chosen tile is tinted with the accent and outlined in its ink, beside
/// the filled check (design-language.md: the accent means "you", and never
/// alone).
/// {@endtemplate}
class AppSelectableRow extends StatelessWidget {
  /// {@macro app_selectable_row}
  const new({
    required this.title,
    required this.selected,
    required this.onPressed,
    this.subtitle,
    this.tile = false,
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

  /// Whether the option is a card of its own rather than a row on one.
  final bool tile;

  @override
  Widget build(BuildContext context) {
    final row = Opacity(
      opacity: onPressed == null ? AppListRow.disabledOpacity : 1,
      child: AppListRow(
        title: title,
        subtitle: subtitle,
        accessory: AppListRowCheckmark(selected: selected),
      ),
    );
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
      child: tile ? _tile(context, row) : InkWell(onTap: onPressed, child: row),
    );
  }

  /// The outline of a chosen [tile].
  static const _outlineWidth = 2.0;

  Widget _tile(BuildContext context, Widget row) {
    final colors = context.appColors;
    final shape = RoundedRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.l)),
      side: selected
          ? BorderSide(color: colors.accentInk, width: _outlineWidth)
          : BorderSide.none,
    );
    return Material(
      color: selected
          ? Color.alphaBlend(
              AppColors.tintedSurface(colors.accentInk),
              colors.surface,
            )
          : colors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
          child: row,
        ),
      ),
    );
  }
}
