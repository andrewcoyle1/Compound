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
///
/// A tab root passes [largeTitle] instead of [appBar]: the title is drawn
/// large above the content and scrolls away with it, and once it has gone
/// the app bar shows it at the standard size (the contract's Titles
/// pattern). [body]'s own vertical scroll view drives it, so that view must
/// not take a controller of its own.
/// {@endtemplate}
class AppScaffold extends StatelessWidget {
  /// {@macro app_scaffold}
  const new({
    this.appBar,
    this.largeTitle,
    this.actions,
    this.body,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.maxWidth = AppContentWidth.readable,
    super.key,
  });

  /// The top bar, as wide as the window. Ignored with a [largeTitle].
  final PreferredSizeWidget? appBar;

  /// A tab root's title, drawn large. The scaffold then builds the app bar,
  /// holding [actions].
  final String? largeTitle;

  /// The app bar's actions beside a [largeTitle].
  final List<Widget>? actions;

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
    final largeTitle = this.largeTitle;
    if (largeTitle != null) {
      return _LargeTitleScaffold(
        title: largeTitle,
        actions: actions,
        body: body,
        bottomNavigationBar: column(bottomNavigationBar),
        backgroundColor: backgroundColor,
        column: column,
      );
    }
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      body: column(body),
      bottomNavigationBar: column(bottomNavigationBar),
    );
  }
}

class _LargeTitleScaffold extends StatefulWidget {
  const new({
    required this.title,
    required this.actions,
    required this.body,
    required this.bottomNavigationBar,
    required this.backgroundColor,
    required this.column,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? body;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final Widget? Function(Widget?) column;

  @override
  State<_LargeTitleScaffold> createState() => _LargeTitleScaffoldState();
}

class _LargeTitleScaffoldState extends State<_LargeTitleScaffold> {
  /// The outer scroll: how far the large title has gone under the bar.
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _titleGone =>
      _scroll.hasClients &&
      _scroll.position.hasContentDimensions &&
      _scroll.position.maxScrollExtent > 0 &&
      _scroll.position.pixels >= _scroll.position.maxScrollExtent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: _scroll,
          builder: (context, _) => AnimatedOpacity(
            opacity: _titleGone ? 1 : 0,
            duration: AppMotion.quick.durationOf(context),
            curve: AppMotion.quick.curve,
            child: Text(widget.title),
          ),
        ),
        actions: widget.actions,
      ),
      backgroundColor: widget.backgroundColor,
      body: widget.column(
        NestedScrollView(
          controller: _scroll,
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  0,
                  AppSpacing.l,
                  AppSpacing.s,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    widget.title,
                    style: AppTextStyles.display.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
          body: widget.body ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: widget.bottomNavigationBar,
    );
  }
}
