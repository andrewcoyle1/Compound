import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';

/// {@template app_readable_width}
/// Centres [child] in a column at most [maxWidth] wide, painting the margins
/// either side in the scaffold's background, so on a tablet or desktop a
/// screen's rows, cards and charts keep phone-like proportions (Swift's
/// `readableContentWidth`). Narrower than [maxWidth], [child] fills the
/// width unchanged.
///
/// Apply it to every page at once with [AppPageTransitionsTheme] rather than
/// screen by screen.
/// {@endtemplate}
class AppReadableWidth extends StatelessWidget {
  /// {@macro app_readable_width}
  const new({
    required this.child,
    this.maxWidth = AppContentWidth.readable,
    super.key,
  });

  /// The screen.
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
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: MediaQuery(
              data: media.copyWith(
                padding: inset(media.padding),
                viewPadding: inset(media.viewPadding),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
