import 'package:flutter/widgets.dart';

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
