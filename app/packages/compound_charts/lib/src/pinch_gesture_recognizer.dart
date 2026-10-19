import 'package:flutter/gestures.dart';

/// A [ScaleGestureRecognizer] that is only ever a pinch: it wins as soon as
/// a second finger lands, and gives up if the first moves past the touch
/// slop before one does. A one-finger drag therefore still reaches the
/// page's vertical scroll and the chart's own horizontal drag, which a
/// plain [ScaleGestureRecognizer] would otherwise compete with.
class PinchGestureRecognizer extends ScaleGestureRecognizer {
  /// Where each finger down went down.
  final _downs = <int, Offset>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _downs[event.pointer] = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent &&
        _downs.length == 1 &&
        (event.position - _downs[event.pointer]!).distance >
            computeHitSlop(event.kind, gestureSettings)) {
      // One finger moving: a scroll or a drag, not a pinch.
      resolve(GestureDisposition.rejected);
      return;
    }
    super.handleEvent(event);
    if (event is PointerDownEvent && _downs.length > 1) {
      resolve(GestureDisposition.accepted);
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _downs.remove(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    _downs.remove(pointer);
    super.rejectGesture(pointer);
  }
}
