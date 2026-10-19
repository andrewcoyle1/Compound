import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';

/// One option of an [AppSegmentedControl].
class AppSegment<T> {
  /// An option.
  const new({required this.value, required this.label, this.semanticLabel});

  /// The value chosen by tapping it.
  final T value;

  /// The short text shown, localized.
  final String label;

  /// What screen readers say instead of [label], when the label is an
  /// abbreviation such as "6M".
  final String? semanticLabel;
}

/// {@template app_segmented_control}
/// A choice between a few options shown side by side: a capsule track with
/// a raised thumb under the chosen one, which slides when the choice
/// changes.
///
/// The track is 32 pt tall at the default text size, inside a 44 pt tap
/// target, and grows with the text. Each option reads as a button in a
/// group of which one is selected, and choosing one plays the selection
/// haptic. With [selected] null no option is chosen yet.
/// {@endtemplate}
class AppSegmentedControl<T> extends StatelessWidget {
  /// {@macro app_segmented_control}
  const new({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// The options, two to five, in order.
  final List<AppSegment<T>> segments;

  /// The chosen option's value, or null when none is chosen.
  final T? selected;

  /// Called with the value of the option chosen, only when it changes.
  /// `null` disables the control.
  final ValueChanged<T>? onChanged;

  // The space above and below the track inside the 44 pt tap target.
  static const double _inset =
      (AppControlSize.row - AppControlSize.segmentedControl) / 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final index = segments.indexWhere((segment) => segment.value == selected);
    final onChanged = this.onChanged;
    final last = segments.length - 1;
    final duration = AppMotion.quick.durationOf(context);

    final track = DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: scheme.surfaceContainerHighest,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: index < 0
            ? const SizedBox.expand()
            : AnimatedAlign(
                duration: duration,
                curve: AppMotion.quick.curve,
                alignment: AlignmentDirectional(
                  last == 0 ? 0 : -1 + 2 * index / last,
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / segments.length,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: const StadiumBorder(),
                      color: scheme.surfaceBright,
                      shadows: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.12),
                          blurRadius: AppSpacing.s,
                          offset: const Offset(0, AppSpacing.xxs),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: _inset),
            child: track,
          ),
        ),
        // Every option as tall as the tallest, so a label that wraps at a
        // large text size leaves no short tap target beside it.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, segment) in segments.indexed)
                Expanded(
                  child: _Segment(
                    segment: segment,
                    selected: i == index,
                    onTap: onChanged == null
                        ? null
                        : () {
                            if (i == index) return;
                            unawaited(HapticFeedback.selectionClick());
                            onChanged(segment.value);
                          },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const new({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final AppSegment<T> segment;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semanticLabel = segment.semanticLabel;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      enabled: onTap != null,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppControlSize.row),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s,
              vertical: AppSegmentedControl._inset + AppSpacing.xs,
            ),
            child: Center(
              child: Text(
                segment.label,
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: onTap == null
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
