import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/dev/gallery/gallery_charts.dart';
import 'package:compound/settings/dev/gallery/gallery_components.dart';
import 'package:compound/settings/dev/gallery/gallery_tokens.dart';

/// The gallery's parts, in the order they appear and in its index.
enum GallerySection {
  tokens,
  buttons,
  rows,
  inputs,
  navigation,
  overlays,
  states,
  content,
  charts;

  /// This part's title.
  String title(AppLocalizations l10n) => switch (this) {
    tokens => l10n.devGalleryTokens,
    buttons => l10n.devGalleryButtons,
    rows => l10n.devGalleryRows,
    inputs => l10n.devGalleryInputs,
    navigation => l10n.devGalleryNavigation,
    overlays => l10n.devGalleryOverlays,
    states => l10n.devGalleryStates,
    content => l10n.devGalleryContent,
    charts => l10n.devGalleryCharts,
  };
}

/// Every `app_ui` and `compound_charts` widget in each of its states, and
/// every token (`ui-contract.md`, rule 7), under Developer Settings in
/// development and staging builds: never in production, where its route is
/// not registered.
///
/// Controls at the top switch the gallery, and what it opens, between light
/// and dark and between three text sizes without touching the device's
/// settings. A new `app_ui` widget gets an entry in `gallery_components.dart`
/// (a chart, in `gallery_charts.dart`) in the same change; a test fails
/// until it does.
class ComponentGalleryPage extends StatefulWidget {
  /// Opens at [section], or the top.
  const new({this.section, super.key});

  /// Under Developer Settings: `/profile/settings/developer/gallery`, with an
  /// optional `?section=buttons`.
  static const path = 'gallery';
  static const name = 'settingsComponentGallery';

  /// Under the gallery: a sample [AppSheetPage].
  static const sheetPath = 'sheet';
  static const sheetName = 'settingsComponentGallerySheet';

  /// The query parameter naming the part to open at.
  static const sectionParameter = 'section';

  /// The part to open at.
  final GallerySection? section;

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  Brightness? _brightness;
  double? _textScale;
  final Map<GallerySection, GlobalKey> _keys = {
    for (final section in GallerySection.values) section: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    if (widget.section case final section?) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _show(section, animate: false),
      );
    }
  }

  void _show(GallerySection section, {bool animate = true}) {
    final context = _keys[section]!.currentContext;
    if (context == null) return;
    const motion = AppMotion.standard;
    Scrollable.ensureVisible(
      context,
      duration: animate ? motion.durationOf(context) : Duration.zero,
      curve: motion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final brightness = _brightness ?? Theme.of(context).brightness;
    final textScale = _textScale;
    return GalleryOverride(
      brightness: brightness,
      textScaler: textScale == null
          ? media.textScaler
          : TextScaler.linear(textScale),
      child: Builder(
        builder: (context) {
          final l10n = context.l10n;
          return AppScaffold(
            appBar: AppBar(title: Text(l10n.devGalleryTitle)),
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Column(
                      spacing: AppSpacing.s,
                      children: [
                        AppSegmentedControl<Brightness>(
                          segments: [
                            AppSegment(
                              value: Brightness.light,
                              label: l10n.devGalleryLight,
                            ),
                            AppSegment(
                              value: Brightness.dark,
                              label: l10n.devGalleryDark,
                            ),
                          ],
                          selected: brightness,
                          onChanged: (value) =>
                              setState(() => _brightness = value),
                        ),
                        AppSegmentedControl<double>(
                          segments: [
                            for (final scale in [1.0, 1.5, 2.0])
                              AppSegment(
                                value: scale,
                                label: AppFormat.percent(
                                  scale,
                                  locale: context.dateLocale,
                                ),
                              ),
                          ],
                          selected: textScale ?? media.textScaler.scale(1),
                          onChanged: (value) =>
                              setState(() => _textScale = value),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(
                      left: AppSpacing.l,
                      right: AppSpacing.l,
                      bottom: AppSpacing.l,
                    ),
                    child: Row(
                      spacing: AppSpacing.s,
                      children: [
                        for (final section in GallerySection.values)
                          AppChip(
                            label: section.title(l10n),
                            onPressed: () => _show(section),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.l,
                        right: AppSpacing.l,
                        bottom: AppSpacing.xxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: AppSpacing.xl,
                        children: [
                          for (final section in GallerySection.values)
                            Column(
                              key: _keys[section],
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: AppSpacing.xl,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    section.title(l10n),
                                    style: AppTextStyles.display,
                                  ),
                                ),
                                ...switch (section) {
                                  GallerySection.tokens => galleryTokens(
                                    context,
                                  ),
                                  GallerySection.buttons => galleryButtons(
                                    context,
                                  ),
                                  GallerySection.rows => galleryRows(context),
                                  GallerySection.inputs => galleryInputs(
                                    context,
                                  ),
                                  GallerySection.navigation =>
                                    galleryNavigation(context),
                                  GallerySection.overlays => galleryOverlays(
                                    context,
                                  ),
                                  GallerySection.states => galleryStates(
                                    context,
                                  ),
                                  GallerySection.content => galleryContent(
                                    context,
                                  ),
                                  GallerySection.charts => galleryCharts(
                                    context,
                                  ),
                                },
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The gallery's chosen [brightness] and [textScaler] for [child], and for
/// the screens and sheets it opens, which wrap themselves in the nearest one
/// with [GalleryOverride.wrap]. iOS alerts draw in the app's own theme: their
/// route takes no theme from the page that opens it.
class GalleryOverride extends StatelessWidget {
  /// Draws [child] in [brightness] at [textScaler].
  const new({
    required this.brightness,
    required this.textScaler,
    required this.child,
    super.key,
  });

  /// Light or dark.
  final Brightness brightness;

  /// The text size.
  final TextScaler textScaler;

  /// The gallery.
  final Widget child;

  /// [child] in the override around [context], to carry it into a route.
  static Widget wrap(BuildContext context, Widget child) {
    final override = context.findAncestorWidgetOfExactType<GalleryOverride>();
    if (override == null) return child;
    return GalleryOverride(
      brightness: override.brightness,
      textScaler: override.textScaler,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
    child: MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(platformBrightness: brightness, textScaler: textScaler),
      child: child,
    ),
  );
}
