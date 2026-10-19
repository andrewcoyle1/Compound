import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Extension on [WidgetTester] to pump a widget inside the app's theme.
extension PumpApp on WidgetTester {
  /// Pumps [widget] in a [Scaffold] under [AppTheme.light] (or [theme]),
  /// with the given text scale and reduced-motion setting, below an
  /// [AppSnackBarScope].
  ///
  /// Animations are off unless a test turns them on, so a shimmering
  /// placeholder or a spinner never keeps `pumpAndSettle` from settling.
  Future<void> pumpApp(
    Widget widget, {
    ThemeData? theme,
    double textScale = 1,
    bool disableAnimations = true,
    bool scaffold = true,
  }) {
    return pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: AppSnackBarScope(child: child!),
        ),
        home: scaffold ? Scaffold(body: widget) : widget,
      ),
    );
  }
}
