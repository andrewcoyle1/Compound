import 'package:material_ui/material_ui.dart';

const _tabular = [FontFeature.tabularFigures()];

/// The type ramp, in the platform's system font (San Francisco on iOS, Roboto
/// on Android). Sizes and line heights are iOS's text styles at the default
/// size, and Flutter scales them with the user's text size setting.
///
/// The styles carry no colour: [Text] takes it from the surrounding
/// [DefaultTextStyle], and a secondary label passes
/// `colorScheme.onSurfaceVariant`.
///
/// | Token | Use |
/// |---|---|
/// | [display] | Hero numbers, onboarding headings |
/// | [metricLarge] | A card's headline number |
/// | [metric] | A stat value |
/// | [metricSmall] | A compact stat, a row's trailing value |
/// | [sectionTitle] | Card and section titles |
/// | [rowTitle] | List row title |
/// | [rowDetail] | Row subtitle, in `onSurfaceVariant` |
/// | [label] | Stat labels and chips, in `onSurfaceVariant` |
///
/// The metric styles use tabular figures, so changing numbers don't jitter.
abstract final class AppTextStyles {
  /// 34, bold: hero numbers, onboarding headings.
  static const display = TextStyle(
    fontSize: 34,
    height: 41 / 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  /// 28, semibold, tabular: a card's headline number.
  static const metricLarge = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );

  /// 20, semibold, tabular: a stat value.
  static const metric = TextStyle(
    fontSize: 20,
    height: 25 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );

  /// 15, semibold, tabular: a compact stat, a row's trailing value.
  static const metricSmall = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );

  /// 17, semibold: card and section titles.
  static const sectionTitle = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  /// 17, regular: a list row's title.
  static const rowTitle = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// 15, regular: a row's subtitle.
  static const rowDetail = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// 12, regular: stat labels and chips.
  static const label = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// The ramp as Material's [TextTheme], so Material widgets use it too.
  /// Plain [Text] reads `bodyMedium`, which is [rowTitle] as on iOS.
  static const textTheme = TextTheme(
    displayLarge: display,
    displayMedium: display,
    displaySmall: display,
    headlineLarge: display,
    headlineMedium: display,
    headlineSmall: metricLarge,
    titleLarge: metric,
    titleMedium: sectionTitle,
    titleSmall: metricSmall,
    bodyLarge: rowTitle,
    bodyMedium: rowTitle,
    bodySmall: rowDetail,
    labelLarge: sectionTitle,
    labelMedium: rowDetail,
    labelSmall: label,
  );
}

/// Icon sizes at the default text size. [of] scales them with the user's
/// text size setting, as SwiftUI's `@ScaledMetric` does.
enum AppIconSize {
  /// 17: inline with body text, row accessories.
  small(17),

  /// 24: a row's leading glyph, toolbar-sized glyphs.
  medium(24),

  /// 44: a card's feature glyph.
  large(44),

  /// 64: empty states and onboarding illustrations.
  hero(64);

  new(this.points);

  /// The size at the default text size.
  final double points;

  /// [points] scaled by the ambient text scaler.
  double of(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(points);
}
