/// Layout metrics. Use a token wherever a number would otherwise be written.
///
/// - `xs`/`s` separate a label from its value or an icon from its text.
/// - `m` separates rows inside a card.
/// - `l` is a card's inner padding, the gap between cards and the screen's
///   side margin.
/// - `xl`/`xxl` separate sections.
///
/// Off-grid values (1, 3, 5, 6, 10, 14) round to the nearest token.
abstract final class AppSpacing {
  /// 2.
  static const double xxs = 2;

  /// 4.
  static const double xs = 4;

  /// 8.
  static const double s = 8;

  /// 12.
  static const double m = 12;

  /// 16. Also the screen's side margin.
  static const double l = 16;

  /// 24.
  static const double xl = 24;

  /// 32.
  static const double xxl = 32;
}

/// Corner radii. Every rounded shape is continuous: draw it with
/// `RoundedSuperellipseBorder`, never a circular-arc `RoundedRectangleBorder`.
/// Capsules (`StadiumBorder`) and circles stay as they are.
///
/// | Radius | Use |
/// |---|---|
/// | `xl` | Full-width cards |
/// | `l`  | Grid tiles |
/// | `m`  | Inline panels |
/// | `s`  | Thumbnails and small controls |
abstract final class AppRadius {
  /// 8: thumbnails and small controls.
  static const double s = 8;

  /// 12: inline panels.
  static const double m = 12;

  /// 16: grid tiles.
  static const double l = 16;

  /// 24: full-width cards.
  static const double xl = 24;
}

/// Fixed control dimensions.
abstract final class AppControlSize {
  /// A leading row glyph's frame.
  static const double icon = 24;

  /// A list row's image.
  static const double thumbnail = 40;

  /// The minimum tap target, on both platforms.
  static const double row = 44;

  /// A list row's minimum height: iOS 26's inset-grouped row.
  static const double listRow = 52;

  /// A call-to-action button's minimum height (Swift's `CallToActionButton`).
  static const double cta = 56;

  /// The app bar's height on iOS, as its navigation bar. Android keeps
  /// Material's 56.
  static const double iosToolbar = 44;
}

/// Chart plot heights.
abstract final class AppChartHeight {
  /// Inside a card.
  static const double compact = 150;

  /// On a detail screen.
  static const double regular = 200;
}

/// The widest a screen's content grows on tablets and desktops. Wider
/// screens centre it, so rows, cards and charts keep phone-like proportions.
abstract final class AppContentWidth {
  /// A routed screen's column.
  static const double readable = 700;

  /// A dashboard's column pair: each column is phone-width.
  static const double dashboard = 1100;

  /// The narrowest a dashboard goes to two columns.
  static const double twoColumns = 740;
}
