import 'package:app_ui/app_ui.dart';

/// {@template app_carousel}
/// [pages] the user swipes through one at a time, each the full width and
/// [height] tall, with dots under them marking the page on screen (Swift's
/// `TabView` with `.page` style). Every page is as tall as the tallest, so
/// controls at their feet line up.
///
/// [height] is at the default text size; it grows with the text, so a
/// page's text still fits at 200%. The dots are hidden from screen readers,
/// which page with the scroll actions instead.
/// {@endtemplate}
class AppCarousel extends StatefulWidget {
  /// {@macro app_carousel}
  const new({required this.height, required this.pages, super.key});

  /// The pages' height at the default text size.
  final double height;

  /// The pages, in order.
  final List<Widget> pages;

  @override
  State<AppCarousel> createState() => _AppCarouselState();
}

class _AppCarouselState extends State<AppCarousel> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      spacing: AppSpacing.m,
      children: [
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(widget.height),
          child: PageView(
            controller: _controller,
            onPageChanged: (page) => setState(() => _page = page),
            children: widget.pages,
          ),
        ),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: AppSpacing.xs,
            children: [
              for (var dot = 0; dot < widget.pages.length; dot++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dot == _page
                        ? scheme.onSurfaceVariant
                        : scheme.outlineVariant,
                  ),
                  child: const SizedBox.square(dimension: 7),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
