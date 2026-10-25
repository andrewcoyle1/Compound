import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _tabular = [FontFeature.tabularFigures()];

/// The display face: Barlow Condensed, bundled in this package under the SIL
/// Open Font License (`assets/fonts/OFL.txt`), in its bold, extra-bold and
/// black weights.
///
/// Two families, because Bold Text must never make a style lighter. Flutter's
/// [Text] answers Bold Text by setting every style to [FontWeight.bold]
/// (700), and a font is picked by the weight drawn in its file, not the one
/// a pubspec declares. So an extra-bold style in a family that holds the
/// bold file would drop to bold. [_display] holds only extra-bold and black:
/// asked for 700, it picks the nearest heavier file, extra-bold, and the
/// style keeps its weight. [_displayBold] holds the bold file for the 700
/// styles, which Bold Text leaves as they are. Neither gets heavier: that
/// needs a variable font or styles that read the setting.
const _display = 'BarlowCondensed';
const _displayBold = 'BarlowCondensedBold';

/// The type ramp, in two faces with one job each (design-language.md):
///
/// - **Barlow Condensed**, bundled with this package, for large titles, hero
///   numbers and stats: [largeTitle], [display], [metricLarge] and [metric].
///   It is narrow, so each style sits a step above the iOS size it replaces.
/// - **The system font** (San Francisco on iOS, Roboto on Android) for
///   everything read: rows, body, buttons, labels and [overline], and
///   [metricSmall], which sits inline with row text.
///
/// The system styles' sizes and line heights are iOS's text styles at the
/// default size, and Flutter scales them all with the user's text size
/// setting.
///
/// On iOS the system-font styles carry Apple's tracking for San Francisco at
/// their size (the HIG's typography table), which SwiftUI applies by itself
/// and Flutter does not; without it SF is set about 5% too wide. Roboto and
/// Barlow are spaced for no tracking. So those styles are getters that read
/// the platform, and [textTheme] passes them on to Material's own widgets.
///
/// The styles carry no colour: [Text] takes it from the surrounding
/// [DefaultTextStyle], and secondary text takes
/// [AppTextStyleColor.secondary].
///
/// | Token | Use |
/// |---|---|
/// | [largeTitle] | A tab root's or onboarding step's large title |
/// | [display] | Hero numbers, a moment's achievement |
/// | [metricLarge] | A card's headline number |
/// | [metric] | A stat value |
/// | [metricSmall] | A compact stat, a row's trailing value |
/// | [sectionTitle] | Card and section titles |
/// | [rowTitle] | List row title |
/// | [rowDetail] | Row subtitle, in secondary text |
/// | [label] | Stat labels and chips, in secondary text |
/// | [overline] | A stat's unit or name over its number, all caps |
///
/// Every number style has tabular figures, so changing numbers don't
/// jitter and columns line up. Barlow's own figures are proportional; its
/// `tnum` feature makes them all one width.
abstract final class AppTextStyles {
  /// 40, extra-bold, condensed: a tab root's large title.
  static const largeTitle = TextStyle(
    fontFamily: _display,
    package: 'app_ui',
    fontSize: 40,
    height: 44 / 40,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );

  /// 44, extra-bold, condensed, tabular: hero numbers.
  static const display = TextStyle(
    fontFamily: _display,
    package: 'app_ui',
    fontSize: 44,
    height: 48 / 44,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );

  /// 34, extra-bold, condensed, tabular: a card's headline number.
  static const metricLarge = TextStyle(
    fontFamily: _display,
    package: 'app_ui',
    fontSize: 34,
    height: 38 / 34,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );

  /// 24, bold, condensed, tabular: a stat value.
  static const metric = TextStyle(
    fontFamily: _displayBold,
    package: 'app_ui',
    fontSize: 24,
    height: 28 / 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    fontFeatures: _tabular,
  );

  /// 15, semibold, system, tabular: a compact stat, a row's trailing value.
  static TextStyle get metricSmall => _system(
    15,
    20,
    FontWeight.w600,
    sfTracking: -0.23,
  ).copyWith(fontFeatures: _tabular);

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

  /// 12, semibold, tracked +0.6: a stat's unit or name over its number
  /// ("KCAL LEFT"). All caps, which a style cannot apply: pass the text
  /// upper-cased (`text.toUpperCase()`). Overlines only, never sentences.
  static TextStyle get overline => _system(
    12,
    16,
    FontWeight.w600,
    sfTracking: 0,
  ).copyWith(letterSpacing: 0.6);

  /// [style] in semibold, as Swift's `.fontWeight(.semibold)`: a token
  /// picked out from the text around it, such as today's date in a strip.
  static TextStyle emphasized(TextStyle style) =>
      style.copyWith(fontWeight: FontWeight.w600);

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

  /// Lists Barlow Condensed's licence on the app's licence page. Call once
  /// at startup.
  static void registerFontLicense() => LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Barlow Condensed',
    ], await rootBundle.loadString('packages/app_ui/assets/fonts/OFL.txt'));
  });

  /// The ramp as Material's [TextTheme], so Material widgets use it too.
  /// Plain [Text] reads `bodyMedium`, which is [rowTitle] as on iOS.
  static TextTheme get textTheme => TextTheme(
    displayLarge: display,
    displayMedium: display,
    displaySmall: largeTitle,
    headlineLarge: largeTitle,
    headlineMedium: largeTitle,
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
  /// This style in semibold. Barlow Condensed, which is bundled without a
  /// semibold, draws it bold.
  TextStyle get semibold => copyWith(fontWeight: FontWeight.w600);
}

/// A style's colour as one of the theme's text greys, instead of
/// `copyWith(color: …)` on each screen: `AppTextStyles.rowDetail.secondary(
/// context)` is a row's subtitle.
extension AppTextStyleColor on TextStyle {
  /// This style in secondary text ([AppColors.secondaryLabel]).
  TextStyle secondary(BuildContext context) =>
      copyWith(color: context.appColors.secondaryLabel);
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
