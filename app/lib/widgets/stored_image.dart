import 'package:app_ui/app_ui.dart';

/// An image the app stored, by the URL it was stored under (Swift
/// `ImageLoaderView`): a Storage download URL, a `data:` URI from the
/// staging flavor's in-memory upload, or a bundled asset's path.
class StoredImage extends StatelessWidget {
  const new(
    this.url, {
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.placeholder = const SizedBox.shrink(),
    super.key,
  });

  /// Where the image is.
  final String url;

  /// How it fills its box.
  final BoxFit fit;

  /// What a screen reader says; none excludes it.
  final String? semanticLabel;

  /// Shown when it cannot be loaded.
  final Widget placeholder;

  @override
  Widget build(BuildContext context) => Image(
    image: storedImageProvider(url),
    fit: fit,
    semanticLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => placeholder,
  );
}

/// A list row's picture (Swift `ListRow(imageName:)`): the stored image, or
/// a plain square where there is none or it cannot be loaded. Decorative:
/// the row's title says what it is.
class StoredThumbnail extends StatelessWidget {
  const new(this.url, {super.key});

  /// Where the image is; none shows the plain square.
  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const SizedBox.expand(),
    );
    final url = this.url;
    if (url == null || url.isEmpty) return placeholder;
    return StoredImage(url, placeholder: placeholder);
  }
}

/// [StoredThumbnail] at a list row's thumbnail size, with its rounded
/// corners, for rows that are not an `AppListRow`.
class RowThumbnail extends StatelessWidget {
  const new(this.url, {super.key});

  final String? url;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.s),
      child: SizedBox.square(
        dimension: MediaQuery.textScalerOf(context)
            .scale(AppControlSize.thumbnail),
        child: StoredThumbnail(url),
      ),
    ),
  );
}

/// A detail screen's picture across its width (Swift's `imageSection` on
/// FoodDetail and RecipeDetail, `imageHeader` on GymProfile), with rounded
/// corners. Decorative unless given a [semanticLabel].
class StoredHeroImage extends StatelessWidget {
  const new(this.url, {this.height = 180, this.semanticLabel, super.key});

  final String url;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    image: semanticLabel != null,
    excludeSemantics: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: StoredImage(url),
      ),
    ),
  );
}

/// The provider for [url], as [StoredImage] reads it.
ImageProvider storedImageProvider(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return NetworkImage(url);
  }
  if (url.startsWith('data:')) {
    // ponytail: decoded once per URI and kept for the session; only the
    // staging flavor makes these, a few photos at most.
    return _dataImages[url] ??= MemoryImage(
      UriData.parse(url).contentAsBytes(),
    );
  }
  return AssetImage(url);
}

final _dataImages = <String, MemoryImage>{};
