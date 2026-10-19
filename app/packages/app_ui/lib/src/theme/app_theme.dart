import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';

/// {@template app_theme}
/// Compound's look as [ThemeData]: the brand on both platforms, not stock
/// Material 3 and not Cupertino.
///
/// Pass [light] and [dark] to `MaterialApp.theme` and `darkTheme`.
///
/// Platform touches are left to Flutter where users expect them: page
/// transitions and the iOS back swipe, adaptive switches and spinners, and
/// the system font with text scaling.
/// {@endtemplate}
abstract final class AppTheme {
  /// The light theme. The accent is black, as `labelColor` is in the Swift
  /// app, with white on it.
  static ThemeData get light => _theme(
    const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF000000),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF000000),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFE5E5EA),
      onSecondaryContainer: Color(0xFF000000),
      error: Color(0xFFFF3B30),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF000000),
      // iOS's secondaryLabel is 3.4:1 on white; this grey passes 4.5:1 on
      // both the surface and the canvas.
      onSurfaceVariant: Color(0xFF6C6C70),
      outline: Color(0xFFC7C7CC),
      outlineVariant: Color(0xFFC6C6C8),
      surfaceContainerHighest: Color(0xFFE5E5EA),
      surfaceContainerHigh: Color(0xFFFFFFFF),
      surfaceTint: Color(0x00000000),
      // A segmented control's thumb, raised on its track.
      surfaceBright: Color(0xFFFFFFFF),
    ),
    AppColors.light,
  );

  /// The dark theme: a white accent with black on it.
  static ThemeData get dark => _theme(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFFFFFF),
      onPrimary: Color(0xFF000000),
      secondary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFF000000),
      secondaryContainer: Color(0xFF2C2C2E),
      onSecondaryContainer: Color(0xFFFFFFFF),
      error: Color(0xFFFF453A),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFF1C1C1E),
      onSurface: Color(0xFFFFFFFF),
      onSurfaceVariant: Color(0xFFAEAEB2),
      outline: Color(0xFF48484A),
      outlineVariant: Color(0xFF38383A),
      surfaceContainerHighest: Color(0xFF2C2C2E),
      surfaceContainerHigh: Color(0xFF2C2C2E),
      surfaceTint: Color(0x00000000),
      surfaceBright: Color(0xFF636366),
    ),
    AppColors.dark,
  );

  static ThemeData _theme(ColorScheme scheme, AppColors colors) {
    const pill = StadiumBorder();
    const minimumSize = Size(AppControlSize.row, AppControlSize.row);
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      textTheme: AppTextStyles.textTheme,
      extensions: [colors],
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
      // The tab bar: the selected tab is marked by the accent alone, as on
      // iOS, with no Material indicator pill.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: const Color(0x00000000),
        indicatorColor: const Color(0x00000000),
        overlayColor: const WidgetStatePropertyAll(Color(0x00000000)),
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: _tabColor(scheme, states),
            size: AppIconSize.medium.points,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) =>
              AppTextStyles.label.copyWith(color: _tabColor(scheme, states)),
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
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(
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
        color: scheme.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minimumSize,
          shape: pill,
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
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : colors.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Color(0x00000000)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        hintStyle: AppTextStyles.rowTitle.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
      ),
    );
  }

  static Color _tabColor(ColorScheme scheme, Set<WidgetState> states) =>
      states.contains(WidgetState.selected)
      ? scheme.primary
      : scheme.onSurfaceVariant;

  static ShapeBorder _continuous(double radius) => RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(radius)),
  );
}
