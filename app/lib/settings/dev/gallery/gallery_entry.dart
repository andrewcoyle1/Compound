import 'package:app_ui/app_ui.dart';
import 'package:compound/settings/dev/gallery/component_gallery_page.dart';

/// One widget's entry in the gallery: its [name] over a card holding each
/// of its [states], built with [galleryInline] or [galleryBlock].
Widget galleryEntry(String name, List<Widget> states, {String? note}) =>
    AppSection(header: name, footer: note, children: states);

/// A state beside its [caption], for a widget about a row's height.
Widget galleryInline(String caption, Widget child) =>
    AppListRow(title: caption, accessory: AppListRowCustom(child));

/// A state under its [caption], full width.
Widget galleryBlock(String caption, Widget child) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    AppListRow(title: caption),
    Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.l,
        right: AppSpacing.l,
        bottom: AppSpacing.l,
      ),
      child: child,
    ),
  ],
);

/// Does nothing: enables a sample button.
void galleryNoop() {}

/// Pushes [page] as a screen, in the gallery's theme and text size.
Future<void> galleryPush(BuildContext context, Widget page) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GalleryOverride.wrap(context, page),
      ),
    );

/// A sample that holds a value of its own, so a toggle or choice in the
/// gallery responds to taps.
class GalleryLive<T> extends StatefulWidget {
  /// Starts at [initial].
  const new({required this.initial, required this.builder, super.key});

  /// The first value.
  final T initial;

  /// Builds the sample from the value and a way to change it.
  final Widget Function(T value, ValueChanged<T> update) builder;

  @override
  State<GalleryLive<T>> createState() => _GalleryLiveState<T>();
}

class _GalleryLiveState<T> extends State<GalleryLive<T>> {
  late T _value = widget.initial;

  @override
  Widget build(BuildContext context) =>
      widget.builder(_value, (value) => setState(() => _value = value));
}
