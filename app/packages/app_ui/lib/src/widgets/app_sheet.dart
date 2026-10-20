import 'package:app_ui/app_ui.dart';

/// The height an [AppSheetPage] or [showAppSheet] sheet opens at: the Swift
/// app's sheet presets (`Presentation.swift`). Every size drags up to full
/// height, so content is never trapped at large text sizes.
enum AppSheetSize {
  /// A short sheet, about a third of the screen (Swift's `.compact`).
  compact(0.35),

  /// A little over half the screen, room for Log Weight's wheels (Swift's
  /// `.half`, the `.medium` detent).
  half(0.6),

  /// Full height (Swift's `.full`).
  full(1);

  new(this.fraction);

  /// The share of the available height the sheet opens at.
  final double fraction;

  /// Text scales above this open every sheet at full height, so less has to
  /// scroll.
  static const largeTextScale = 1.3;
}

/// {@template app_sheet_page}
/// A routed page shown as a sheet of [size], for a `GoRoute`'s
/// `pageBuilder`: a modal bottom sheet in `canvas` with a drag handle, which
/// opens at [size] and drags up to full height. Dragging it down far enough,
/// or tapping outside, closes it.
///
/// The sheet's scroll controller is [child]'s primary one: a vertical list
/// inside that sets no controller of its own moves the sheet as it scrolls.
/// {@endtemplate}
class AppSheetPage<T> extends Page<T> {
  /// {@macro app_sheet_page}
  const new({
    required this.child,
    this.size = AppSheetSize.half,
    super.key,
    super.name,
  });

  /// The sheet's content, usually a [Scaffold] whose body is a list.
  final Widget child;

  /// The height it opens at.
  final AppSheetSize size;

  @override
  Route<T> createRoute(BuildContext context) => ModalBottomSheetRoute<T>(
    settings: this,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // The colours come from the theme's bottomSheetTheme when the sheet
    // builds, so they follow the app's theme and brightness.
    sheetAnimationStyle: _animation(context),
    builder: (_) => _AppSheetBody(size: size, child: child),
  );
}

/// Shows [builder]'s content as a sheet of [size] over [context]'s screen
/// and returns what it is closed with. See [AppSheetPage].
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  AppSheetSize size = AppSheetSize.half,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  sheetAnimationStyle: _animation(context),
  builder: (context) => _AppSheetBody(size: size, child: builder(context)),
);

AnimationStyle? _animation(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false
    ? AnimationStyle.noAnimation
    : null;

class _AppSheetBody extends StatelessWidget {
  const new({required this.size, required this.child});

  final AppSheetSize size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final large =
        MediaQuery.textScalerOf(context).scale(1) > AppSheetSize.largeTextScale;
    final initial = large ? 1.0 : size.fraction;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: initial,
      snap: true,
      snapSizes: [if (initial < 1) initial],
      builder: (context, controller) =>
          PrimaryScrollController(controller: controller, child: child),
    );
  }
}
