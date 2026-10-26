import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart' show ProgressPhotoModel;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/widgets/stored_image.dart';

/// The two photos to compare, older first, with their captions (Swift
/// `ProgressPhotoCompareDelegate`).
class const ProgressPhotoComparison({
  /// The older photo.
  required final ProgressPhotoModel before,

  /// The newer photo.
  required final ProgressPhotoModel after,

  /// The older photo's caption.
  required final String beforeCaption,

  /// The newer photo's caption.
  required final String afterCaption,
});

/// Two photos side by side, or one over the other with a slider that wipes
/// between them (Swift `ProgressPhotoCompareView`). Holds no state beyond
/// its own layout, as in Swift.
class ProgressPhotoComparePage extends StatefulWidget {
  const new({required this.comparison, super.key});

  /// Under Progress Photos: `/progress/body-metrics/photos/compare`, with
  /// the [ProgressPhotoComparison] as the route's `extra`.
  static const path = 'compare';
  static const name = 'progressPhotoCompare';

  final ProgressPhotoComparison comparison;

  @override
  State<ProgressPhotoComparePage> createState() =>
      _ProgressPhotoComparePageState();
}

enum _Mode { sideBySide, slider }

class _ProgressPhotoComparePageState extends State<ProgressPhotoComparePage> {
  _Mode _mode = _Mode.sideBySide;

  /// How much of the older photo shows, from the leading edge.
  var _split = 0.5;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final comparison = widget.comparison;
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.progressPhotosCompare)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppContentWidth.readable,
            ),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                Semantics(
                  label: l10n.progressPhotoCompareLayout,
                  child: AppSegmentedControl<_Mode>(
                    segments: [
                      AppSegment(
                        value: _Mode.sideBySide,
                        label: l10n.progressPhotoCompareSideBySide,
                      ),
                      AppSegment(
                        value: _Mode.slider,
                        label: l10n.progressPhotoCompareSlider,
                      ),
                    ],
                    selected: _mode,
                    onChanged: (mode) => setState(() => _mode = mode),
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                switch (_mode) {
                  _Mode.sideBySide => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.s,
                    children: [
                      Expanded(
                        child: _Column(
                          photo: comparison.before,
                          caption: comparison.beforeCaption,
                        ),
                      ),
                      Expanded(
                        child: _Column(
                          photo: comparison.after,
                          caption: comparison.afterCaption,
                        ),
                      ),
                    ],
                  ),
                  _Mode.slider => _slider(context),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _slider(BuildContext context) {
    final l10n = context.l10n;
    final comparison = widget.comparison;
    final captionStyle = AppTextStyles.label.secondary(context);
    return Column(
      spacing: AppSpacing.m,
      children: [
        Semantics(
          label: l10n.progressPhotoCompareOver(
            comparison.beforeCaption,
            comparison.afterCaption,
          ),
          image: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.m),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth * _split;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      _Photo(comparison.after),
                      ClipRect(
                        clipper: _LeadingClipper(width),
                        child: _Photo(comparison.before),
                      ),
                      Positioned(
                        left: width - 1,
                        top: 0,
                        bottom: 0,
                        // White in both modes, over the photos, as Swift's.
                        child: SizedBox(
                          width: 2,
                          child: ColoredBox(color: AppColors.light.surface),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        Row(
          children: [
            Text(l10n.progressPhotoCompareBefore, style: AppTextStyles.label),
            Expanded(
              child: Slider.adaptive(
                value: _split,
                semanticFormatterCallback: (value) =>
                    '${l10n.progressPhotoCompareReveal} '
                    '${AppFormat.percent(value)}',
                onChanged: (value) => setState(() => _split = value),
              ),
            ),
            Text(l10n.progressPhotoCompareAfter, style: AppTextStyles.label),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(comparison.beforeCaption, style: captionStyle),
            ),
            Flexible(
              child: Text(
                comparison.afterCaption,
                style: captionStyle,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const new({required this.photo, required this.caption});

  final ProgressPhotoModel photo;
  final String caption;

  @override
  Widget build(BuildContext context) => Column(
    spacing: AppSpacing.s,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: _Photo(photo, semanticLabel: caption),
        ),
      ),
      Text(
        caption,
        style: AppTextStyles.label.secondary(context),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _Photo extends StatelessWidget {
  const new(this.photo, {this.semanticLabel});

  final ProgressPhotoModel photo;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final url = photo.imageUrl;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: url == null
          ? null
          : StoredImage(url, semanticLabel: semanticLabel),
    );
  }
}

/// Keeps the leading [width] of its child.
class _LeadingClipper extends CustomClipper<Rect> {
  new(this.width);

  final double width;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, width, size.height);

  @override
  bool shouldReclip(_LeadingClipper oldClipper) => oldClipper.width != width;
}
