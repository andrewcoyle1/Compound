import 'package:app_ui/app_ui.dart';

/// {@template app_chip}
/// A capsule label: a tag, a filter or a badge.
///
/// Unselected it is [tint] on `tintedSurface(tint)`. Selected it is a solid
/// [tint] with `onPrimary` text. Leave [tint] as the accent for anything
/// selectable, and pass a data colour only for a chip that carries that
/// data's meaning.
///
/// With [onPressed] it is a button whose tap target is padded out to the
/// 44 pt minimum; the capsule itself stays small.
/// {@endtemplate}
class AppChip extends StatelessWidget {
  /// {@macro app_chip}
  const new({
    required this.label,
    this.icon,
    this.tint,
    this.selected = false,
    this.onPressed,
    super.key,
  });

  /// The chip's text, localized.
  final String label;

  /// An icon before the text.
  final IconData? icon;

  /// The chip's colour. Defaults to the accent.
  final Color? tint;

  /// Whether the chip is selected: filled, and announced as selected.
  final bool selected;

  /// Makes the chip a button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = this.tint ?? scheme.primary;
    final foreground = selected ? scheme.onPrimary : tint;
    final icon = this.icon;
    final style = AppTextStyles.label.copyWith(
      fontWeight: FontWeight.w600,
      color: foreground,
    );
    final chip = DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: selected ? tint : AppColors.tintedSurface(tint),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
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
            Text(label, style: style),
          ],
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
