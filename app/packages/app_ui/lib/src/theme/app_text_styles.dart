import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

const _tabular = [FontFeature.tabularFigures()];

/// The rounded face for numbers: Nunito, bundled in this package under the
/// SIL Open Font License, in the two weights used. Nunito is drawn lighter
/// than SF Rounded, so each style takes one weight up from Swift's to look
/// as heavy: bold for semibold, extra-bold for bold.
const _rounded = 'Nunito';

/// The type ramp. Numbers ([display] and the metric styles) are set in
/// Nunito, a rounded face bundled with this package, as Swift's are in SF
/// Rounded; the rest are in the platform's system font (San Francisco on
/// iOS, Roboto on Android). Sizes and line heights are iOS's text styles at
/// the default size, and Flutter scales them with the user's text size
/// setting.
///
/// On iOS the system-font styles carry Apple's tracking for San Francisco at
/// their size (the HIG's typography table), which SwiftUI applies by itself
/// and Flutter does not; without it SF is set about 5% too wide. Roboto and
/// Nunito are spaced for no tracking. So those styles are getters that read
/// the platform, and [textTheme] passes them on to Material's own widgets.
///
/// The styles carry no colour: [Text] takes it from the surrounding
/// [DefaultTextStyle], and a secondary label passes
/// `colorScheme.onSurfaceVariant`.
///
/// | Token | Use |
/// |---|---|
/// | [display] | Hero numbers, onboarding headings, a tab's large title |
/// | [metricLarge] | A card's headline number |
/// | [metric] | A stat value |
/// | [metricSmall] | A compact stat, a row's trailing value |
/// | [sectionTitle] | Card and section titles |
/// | [rowTitle] | List row title |
/// | [rowDetail] | Row subtitle, in `onSurfaceVariant` |
/// | [label] | Stat labels, in `onSurfaceVariant` |
/// | [labelEmphasized] | Chips and capsules |
///
/// The metric styles use tabular figures, so changing numbers don't jitter.
/// Nunito's figures are tabular by default; the feature is asked for anyway.
abstract final class AppTextStyles {
  /// 34, bold (Nunito extra-bold), rounded: hero numbers, onboarding
  /// headings.
  static const display = TextStyle(
    fontFamily: _rounded,
    package: 'app_ui',
    fontSize: 34,
    height: 41 / 34,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  /// 28, semibold (Nunito bold), rounded, tabular: a card's headline number.
  static const metricLarge = TextStyle(
    fontFamily: _rounded,
    package: 'app_ui',
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );

  /// 20, semibold (Nunito bold), rounded, tabular: a stat value.
  static const metric = TextStyle(
    fontFamily: _rounded,
    package: 'app_ui',
    fontSize: 20,
    height: 25 / 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );

  /// 15, semibold (Nunito bold), rounded, tabular: a compact stat, a row's
  /// trailing value.
  static const metricSmall = TextStyle(
    fontFamily: _rounded,
    package: 'app_ui',
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );

  /// 17, semibold: card and section titles.
  static TextStyle get sectionTitle =>
      _system(17, 22, FontWeight.w600, sfTracking: -0.43);

  /// 17, regular: a list row's title.
  static TextStyle get rowTitle =>
      _system(17, 22, FontWeight.w400, sfTracking: -0.43);

  /// 15, regular: a row's subtitle.
  static TextStyle get rowDetail =>
      _system(15, 20, FontWeight.w400, sfTracking: -0.23);

  /// 12, regular: stat labels and chips.
  static TextStyle get label => _system(12, 16, FontWeight.w400, sfTracking: 0);

  /// 12, semibold: a chip's or a capsule's text.
  static TextStyle get labelEmphasized =>
      _system(12, 16, FontWeight.w600, sfTracking: 0);

  /// A system-font style. [sfTracking] is Apple's tracking for San Francisco
  /// at [size], in points, applied on iOS only.
  static TextStyle _system(
    double size,
    double lineHeight,
    FontWeight weight, {
    required double sfTracking,
  }) => TextStyle(
    // Named, as Material's typography names it, rather than left to the
    // engine's default: a component style (a button's label) replaces the
    // ambient style instead of merging with it, so without a family it was
    // set in whatever face the engine falls back to.
    fontFamily: switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 'CupertinoSystemText',
      _ => 'Roboto',
    },
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    letterSpacing: defaultTargetPlatform == TargetPlatform.iOS ? sfTracking : 0,
  );

  /// Lists Nunito's licence on the app's licence page. Call once at startup.
  static void registerFontLicense() => LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Nunito',
    ], await rootBundle.loadString('packages/app_ui/assets/fonts/OFL.txt'));
  });

  /// The ramp as Material's [TextTheme], so Material widgets use it too.
  /// Plain [Text] reads `bodyMedium`, which is [rowTitle] as on iOS.
  static TextTheme get textTheme => TextTheme(
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

/// The weight a style takes for emphasis, as Swift's `.weight(.semibold)` on
/// one of its fonts: `AppTextStyles.label.semibold` is the tracker's rest
/// countdown, `AppTextStyles.rowDetail.semibold` a set's number. A title is
/// [AppTextStyles.sectionTitle], not `rowTitle.semibold`.
extension AppTextStyleWeight on TextStyle {
  /// This style in semibold. Nunito, which has no semibold, draws it bold.
  TextStyle get semibold => copyWith(fontWeight: FontWeight.w600);
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
