import 'package:flutter/material.dart';

/// A route's page shown as the Swift app's `.half` sheet
/// (`ResizableSheetConfig.half`): a modal bottom sheet with a drag handle
/// that opens at a little over half the screen (room for Log Weight's
/// wheels on a phone) and drags up to full height, Swift's `.medium` and
/// `.large` detents. Dragging it down far enough closes it.
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
        initialChildSize: large ? 1 : 0.6,
        snap: true,
        snapSizes: const [0.6],
        builder: (context, controller) =>
            PrimaryScrollController(controller: controller, child: child),
      );
    },
  );
}
