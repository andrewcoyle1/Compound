import 'package:app_ui/app_ui.dart';

/// {@template app_card_style}
/// The fill and corner radius of an [AppCard].
///
/// | Style | Fill | Radius | Use |
/// |---|---|---|---|
/// | [card] | `surface` | `AppRadius.xl` | Full-width cards |
/// | [tile] | `surface` | `AppRadius.l` | Grid tiles |
/// | [AppCardStyle.tinted] | `tintedSurface` | `AppRadius.l` | A data tile |
/// {@endtemplate}
final class AppCardStyle {
  const new _(this.radius, [this.tint]);

  /// {@macro app_card_style}
  const new tinted(Color tint) : this._(AppRadius.l, tint);

  /// A full-width card.
  static const card = AppCardStyle._(AppRadius.xl);

  /// A grid tile.
  static const tile = AppCardStyle._(AppRadius.l);

  /// The corner radius.
  final double radius;

  /// The data colour of a tinted tile; `null` for the plain surface.
  final Color? tint;
}

/// {@template app_card}
/// A card surface behind [child], with continuous corners. Padding stays the
/// caller's job. Ink from buttons inside it draws on the card.
/// {@endtemplate}
class AppCard extends StatelessWidget {
  /// {@macro app_card}
  const new({required this.child, this.style = AppCardStyle.card, super.key});

  /// The card's content.
  final Widget child;

  /// The card's fill and radius.
  final AppCardStyle style;

  @override
  Widget build(BuildContext context) {
    final tint = style.tint;
    return Material(
      color: tint == null
          ? context.appColors.surface
          : AppColors.tintedSurface(tint),
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(style.radius)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
