import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';

/// {@template app_theme}
/// Compound's look as [ThemeData]: the brand on both platforms, not stock
/// Material 3 and not Cupertino.
///
/// Pass [light], [dark] and [lightHighContrast] to `MaterialApp.theme`,
/// `darkTheme` and `highContrastTheme`.
///
/// Platform touches are left to Flutter where users expect them: page
/// transitions and the iOS back swipe, adaptive switches and spinners, and
/// the system font with text scaling.
/// {@endtemplate}
abstract final class AppTheme {
  /// Volt, the accent: a fill in both modes, with [_onVolt] on it.
  static const _volt = Color(0xFFC8F31D);
  static const _onVolt = Color(0xFF000000);

  /// The light theme: volt fills with black on them, and the accent as text
  /// in [AppColors.accentInk]'s dark olive.
  static ThemeData get light => _theme(Brightness.light, AppColors.light);

  /// The dark theme, which the design starts from: volt on black.
  static ThemeData get dark => _theme(Brightness.dark, AppColors.dark);

  /// [light] under Increase Contrast (`MaterialApp.highContrastTheme`): the
  /// accent's text darkens to `#3A4D00` (9.4:1 on white), and volt buttons
  /// and the selected tab's capsule gain a 1 pt black outline, since volt
  /// on white is 1.3:1. Dark mode needs no variant: volt on black is 16:1.
  static ThemeData get lightHighContrast => _theme(
    Brightness.light,
    AppColors.light.copyWith(accentInk: const Color(0xFF3A4D00)),
    highContrast: true,
  );

  static ColorScheme _scheme(Brightness brightness, AppColors colors) {
    final light = brightness == Brightness.light;
    final label = light ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    return ColorScheme(
      brightness: brightness,
      primary: _volt,
      onPrimary: _onVolt,
      secondary: _volt,
      onSecondary: _onVolt,
      secondaryContainer: colors.raised,
      onSecondaryContainer: label,
      error: colors.danger,
      onError: const Color(0xFFFFFFFF),
      surface: colors.surface,
      onSurface: label,
      // iOS's secondaryLabel is 3.4:1 on white; this grey passes 4.5:1 on
      // both the surface and the canvas.
      onSurfaceVariant: colors.secondaryLabel,
      outline: light ? const Color(0xFFC7C7CC) : const Color(0xFF48484A),
      outlineVariant: colors.separator,
      surfaceContainerHighest: colors.raised,
      surfaceContainerHigh: light ? colors.surface : colors.raised,
      surfaceTint: const Color(0x00000000),
      // A segmented control's thumb, raised on its track.
      surfaceBright: light ? colors.surface : const Color(0xFF636366),
    );
  }

  static ThemeData _theme(
    Brightness brightness,
    AppColors colors, {
    bool highContrast = false,
  }) {
    final scheme = _scheme(brightness, colors);
    // Increase Contrast's 1 pt black outline on a volt fill.
    final voltEdge = highContrast ? const BorderSide() : BorderSide.none;
    // A capsule at one line, as on iOS. A label that wraps at a large text
    // size keeps capsule-sized corners rather than turning the button into
    // an oval that clips its text.
    const pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppControlSize.cta / 2)),
    );
    final filledPill = pill.copyWith(side: voltEdge);
    const minimumSize = Size(AppControlSize.row, AppControlSize.row);
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      textTheme: AppTextStyles.textTheme,
      extensions: [colors],
      // Press feedback is the one thing that follows the platform: a ripple
      // on Android, and on iOS only the pressed highlight, as a tapped iOS
      // control dims rather than splashes.
      splashFactory: defaultTargetPlatform == TargetPlatform.iOS
          ? NoSplash.splashFactory
          : null,
      iconTheme: IconThemeData(
        color: scheme.onSurface,
        size: AppIconSize.medium.points,
      ),
      // Titles centred on both platforms, as on iOS. Flutter would centre an
      // iOS title only with fewer than two actions.
      appBarTheme: AppBarTheme(
        centerTitle: true,
        toolbarHeight: defaultTargetPlatform == TargetPlatform.iOS
            ? AppControlSize.iosToolbar
            : null,
        backgroundColor: colors.canvas,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTextStyles.sectionTitle.copyWith(
          color: scheme.onSurface,
        ),
      ),
      // The tab bar: AppTabBar's card supplies the fill, and the selected
      // tab's filled glyph sits on a volt capsule, in black, over a bold
      // label: never the accent alone, which is faint on white.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0x00000000),
        surfaceTintColor: const Color(0x00000000),
        indicatorColor: scheme.primary,
        indicatorShape: StadiumBorder(side: voltEdge),
        overlayColor: const WidgetStatePropertyAll(Color(0x00000000)),
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
            size: AppIconSize.medium.points,
          ),
        ),
        // One line, cut short with an ellipsis where a word is wider than
        // its tab ("Entrenamiento"), rather than broken onto a clipped
        // second line.
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppTextStyles.label.semibold.copyWith(
                  color: scheme.onSurface,
                  overflow: TextOverflow.ellipsis,
                )
              : AppTextStyles.label.copyWith(
                  color: scheme.onSurfaceVariant,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: _continuous(AppRadius.xl),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: _continuous(AppRadius.xl),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.canvas,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        // A hairline edge, so a dark sheet stays apart from the black
        // screen under it.
        shape: RoundedSuperellipseBorder(
          side: BorderSide(color: scheme.outlineVariant, width: 0.5),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        shape: _continuous(AppRadius.m),
        textStyle: AppTextStyles.rowTitle.copyWith(color: scheme.onSurface),
      ),
      dividerTheme: DividerThemeData(
        color: colors.separator,
        thickness: 0.5,
        space: 0.5,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minimumSize,
          shape: filledPill,
          // Swift's CTA label is body, not headline.
          textStyle: AppTextStyles.rowTitle,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.m,
          ),
          // Disabled, the accent fill goes, so onPrimary would sit on grey.
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minimumSize,
          shape: pill,
          textStyle: AppTextStyles.rowTitle,
          // The accent as text: accentInk, as volt on white is unreadable.
          foregroundColor: colors.accentInk,
        ),
      ),
      switchTheme: SwitchThemeData(
        // Off, the thumb is the secondary label colour: the surface colour
        // it used to be all but vanished on the dark track.
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        // Disabled and on, the accent is faded, so it no longer looks like
        // a switch that can be turned off.
        trackColor: WidgetStateProperty.resolveWith(
          (states) => !states.contains(WidgetState.selected)
              ? scheme.surfaceContainerHighest
              : states.contains(WidgetState.disabled)
              ? scheme.primary.withValues(alpha: 0.38)
              : scheme.primary,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Color(0x00000000)),
      ),
      // A progress stroke is a line on its track, so it takes accentInk:
      // volt on the light track is 1.03:1.
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accentInk,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      // The caret and selection are the accent drawn on a field, so its ink:
      // a volt caret vanishes on white.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accentInk,
        selectionHandleColor: colors.accentInk,
        selectionColor: colors.accentInk.withValues(alpha: 0.3),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.raised,
        hintStyle: AppTextStyles.rowTitle.copyWith(color: colors.tertiaryLabel),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
      ),
    );
  }

  static ShapeBorder _continuous(double radius) => RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(radius)),
  );
}
