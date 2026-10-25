import 'package:app_ui/app_ui.dart';

/// The size of an [AppChip].
enum AppChipSize {
  /// A small capsule: a tag, a badge or a filter among content.
  regular,

  /// A filter bar's chip (Swift's `BarChip`): [AppControlSize.row] tall,
  /// in the row title's size. Unselected it is the text colour on
  /// `surface`, so a bar of them reads as controls rather than tags.
  large,
}

/// {@template app_chip}
/// A capsule label: a tag, a filter or a badge.
///
/// Unselected it is the text colour on `raised`, or [tint] on
/// `tintedSurface(tint)` when one is passed. Selected it is a solid [tint]
/// (volt by default) with `onPrimary` text. Leave [tint] unset for anything
/// selectable, and pass a data colour only for a chip that carries that
/// data's meaning.
///
/// With [onPressed] it is a button whose tap target is padded out to the
/// 44 pt minimum; the capsule itself stays small. An [AppChipSize.large]
/// chip is a full 44 pt itself.
/// {@endtemplate}
class AppChip extends StatelessWidget {
  /// {@macro app_chip}
  const new({
    required this.label,
    this.icon,
    this.tint,
    this.selected = false,
    this.onPressed,
    this.size = AppChipSize.regular,
    super.key,
  });

  /// The chip's text, localized.
  final String label;

  /// An icon before the text.
  final IconData? icon;

  /// The chip's colour. Unset, a chip is neutral, and volt when
  /// [selected].
  final Color? tint;

  /// Whether the chip is selected: filled, and announced as selected.
  final bool selected;

  /// Makes the chip a button.
  final VoidCallback? onPressed;

  /// The chip's size.
  final AppChipSize size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Selected, the default is a volt fill. Unselected and untinted it is
    // neutral, the text colour on `raised`: the accent marks only what the
    // user chose (design-language.md).
    final tint = this.tint;
    final large = size == AppChipSize.large;
    final foreground = selected
        ? scheme.onPrimary
        : large || tint == null
        ? scheme.onSurface
        : tint;
    final icon = this.icon;
    final style = large
        ? AppTextStyles.rowTitle.copyWith(color: foreground)
        : AppTextStyles.label.semibold.copyWith(color: foreground);
    final chip = DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: selected
            ? tint ?? scheme.primary
            : large
            ? context.appColors.surface
            : tint == null
            ? context.appColors.raised
            : AppColors.tintedSurface(tint),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: large ? AppControlSize.row : 0),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: large ? AppSpacing.m : AppSpacing.s,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xs,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  color: foreground,
                  size: MediaQuery.textScalerOf(context).scale(style.fontSize!),
                ),
              // Wraps when the label is wider than the space it is given.
              Flexible(child: Text(label, style: style)),
            ],
          ),
        ),
      ),
    );
    final onPressed = this.onPressed;
    if (onPressed == null) return Semantics(selected: selected, child: chip);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppControlSize.row,
            minHeight: AppControlSize.row,
          ),
          child: Align(widthFactor: 1, heightFactor: 1, child: chip),
        ),
      ),
    );
  }
}
