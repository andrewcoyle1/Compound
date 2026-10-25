import 'package:app_ui/app_ui.dart';

/// {@template app_swatch}
/// A circle in a colour the user chose or the data has: a plate's colour, a
/// mesocycle's colour and glyph.
///
/// Without [icon] it is a solid fill; with one, the colour's tinted surface
/// with the glyph in the colour. [selected] rings it in the accent
/// ([AppSelectionRing]), for a picker. [size] is the diameter at the default
/// text size, and grows with the text. Decorative: the caller labels it.
/// {@endtemplate}
class AppSwatch extends StatelessWidget {
  /// {@macro app_swatch}
  const new({
    required this.color,
    this.icon,
    this.size = AppIconSize.large,
    this.selected = false,
    super.key,
  });

  /// The colour.
  final Color color;

  /// A glyph, from [AppSymbols] or the data's own.
  final IconData? icon;

  /// The circle's diameter.
  final AppIconSize size;

  /// Whether it is the picked one.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    final diameter = size.of(context);
    return ExcludeSemantics(
      child: AppSelectionRing(
        selected: selected,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: const CircleBorder(),
            color: icon == null ? color : AppColors.tintedSurface(color),
          ),
          child: SizedBox.square(
            dimension: diameter,
            child: icon == null
                ? null
                : Icon(icon, size: diameter * 0.55, color: color),
          ),
        ),
      ),
    );
  }
}
