import 'package:app_ui/app_ui.dart';

/// {@template app_page_transitions_theme}
/// The platform's page transitions, with every page route's screen in an
/// [AppReadableWidth] column: [AppContentWidth.readable] wide unless
/// [maxWidths] names the route, as it would for a tab root laid out as an
/// [AppDashboard] ([AppContentWidth.dashboard]) or the page holding the tab
/// bar (`double.infinity`).
///
/// Pass it as `ThemeData.pageTransitionsTheme` so the column is set once,
/// for every route, as the Swift app sets `readableContentWidth` once at its
/// root.
/// {@endtemplate}
class AppPageTransitionsTheme extends PageTransitionsTheme {
  /// {@macro app_page_transitions_theme}
  const new({this.maxWidths = const {}, super.builders});

  /// Column widths by route name (`RouteSettings.name`), for the routes
  /// whose column is not [AppContentWidth.readable].
  final Map<String, double> maxWidths;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => super.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    AppReadableWidth(
      maxWidth: maxWidths[route.settings.name] ?? AppContentWidth.readable,
      child: child,
    ),
  );
}
