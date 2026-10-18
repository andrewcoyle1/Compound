import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';

/// {@template app_readable_width}
/// Centres [child] in a column at most [maxWidth] wide, so on a tablet or
/// desktop a screen's rows, cards and charts keep phone-like proportions
/// (Swift's `readableContentWidth`). Narrower than [maxWidth], [child] fills
/// the width unchanged.
///
/// Screens get it through [AppScaffold] rather than using it directly.
/// {@endtemplate}
class AppReadableWidth extends StatelessWidget {
  /// {@macro app_readable_width}
  const new({
    required this.child,
    this.maxWidth = AppContentWidth.readable,
    super.key,
  });

  /// The content.
  final Widget child;

  /// The widest the column grows.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = math.max<double>(
          0,
          (constraints.maxWidth - maxWidth) / 2,
        );
        // The margin already clears a landscape notch, so the column only
        // keeps whatever safe-area inset the margin doesn't cover.
        EdgeInsets inset(EdgeInsets padding) => padding.copyWith(
          left: math.max<double>(0, padding.left - gutter),
          right: math.max<double>(0, padding.right - gutter),
        );
        final media = MediaQuery.of(context);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: MediaQuery(
            data: media.copyWith(
              padding: inset(media.padding),
              viewPadding: inset(media.viewPadding),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// {@template app_scaffold}
/// A routed screen's [Scaffold]: the app bar spans the window, as Swift's
/// navigation bar does, while [body] and [bottomNavigationBar] (the bottom
/// CTA) sit in an [AppReadableWidth] column [maxWidth] wide. Every screen
/// uses it in place of [Scaffold]; only the page holding the tab bar,
/// which spans the window, does not.
/// {@endtemplate}
class AppScaffold extends StatelessWidget {
  /// {@macro app_scaffold}
  const new({
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.maxWidth = AppContentWidth.readable,
    super.key,
  });

  /// The top bar, as wide as the window.
  final PreferredSizeWidget? appBar;

  /// The screen's content, in the column.
  final Widget? body;

  /// The bottom CTA, in the column.
  final Widget? bottomNavigationBar;

  /// The background, which fills the window.
  final Color? backgroundColor;

  /// The column's width: [AppContentWidth.dashboard] for a tab root laid
  /// out as an [AppDashboard] (Swift's `preferredReadableContentWidth`).
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    Widget? column(Widget? child) => child == null
        ? null
        : AppReadableWidth(maxWidth: maxWidth, child: child);
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      body: column(body),
      bottomNavigationBar: column(bottomNavigationBar),
    );
  }
}
