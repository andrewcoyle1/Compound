import 'package:flutter/material.dart';

/// A route's page shown as the Swift app's `.half` sheet
/// (`ResizableSheetConfig.half`): a modal bottom sheet with a drag handle
/// that opens at half the screen and drags up to full height, its `.medium`
/// and `.large` detents. Dragging it down far enough closes it.
///
/// At large text sizes it opens at full height, so less has to scroll. The
/// sheet's scroll controller is [child]'s primary one: a vertical list
/// inside that sets no controller of its own moves the sheet as it scrolls.
class HalfSheetPage<T> extends Page<T> {
  const new({required this.child, super.key, super.name});

  /// The sheet's content, usually a [Scaffold] whose body is a list.
  final Widget child;

  /// Text scales above this open the sheet at full height.
  static const largeTextScale = 1.3;

  @override
  Route<T> createRoute(BuildContext context) => ModalBottomSheetRoute<T>(
    settings: this,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // One colour from the handle down to the page under it.
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (context) {
      final large = MediaQuery.textScalerOf(context).scale(1) > largeTextScale;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: large ? 1 : 0.5,
        snap: true,
        snapSizes: const [0.5],
        builder: (context, controller) =>
            PrimaryScrollController(controller: controller, child: child),
      );
    },
  );
}
