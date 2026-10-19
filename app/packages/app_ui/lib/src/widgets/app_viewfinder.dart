import 'package:app_ui/app_ui.dart';

/// {@template app_viewfinder}
/// A live camera's box: the [preview] filling a rounded 4:3 frame, with a
/// guide drawn inside it for what to hold in view, a [caption] saying what
/// is happening ("Hold the label in the frame", "Reading label…"), and an
/// [action] at the top trailing corner, such as the torch.
///
/// Without a preview (the camera is opening, closed or refused) the box
/// shows a camera glyph and no guide. The guide and the caption's scrim are
/// white and black in both themes, because they sit over the camera's
/// picture rather than the app. Screen readers hear the caption whenever it
/// changes.
/// {@endtemplate}
class AppViewfinder extends StatelessWidget {
  /// {@macro app_viewfinder}
  const new({
    this.preview,
    this.caption,
    this.busy = false,
    this.action,
    super.key,
  });

  /// What the camera sees, filling the box; null while there is none.
  final Widget? preview;

  /// What is happening, localized, over the bottom of the box.
  final String? caption;

  /// Whether to show a spinner before the caption.
  final bool busy;

  /// A button at the top trailing corner, usually an [AppIconButton].
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = this.preview;
    final caption = this.caption;
    final action = this.action;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.l),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (preview != null) ...[
                ExcludeSemantics(child: preview),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                  ),
                ),
              ] else
                Center(
                  child: Icon(
                    AppSymbols.camera,
                    size: AppIconSize.large.of(context),
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (caption != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: _Caption(text: caption, busy: busy),
                  ),
                ),
              if (action != null)
                Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s),
                    child: action,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const new({required this.text, required this.busy});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.label.copyWith(color: Colors.white);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.s,
            children: [
              if (busy)
                SizedBox.square(
                  dimension: MediaQuery.textScalerOf(context)
                      .scale(style.fontSize!),
                  child: const AppSpinner(
                    size: AppSpinnerSize.small,
                    color: Colors.white,
                  ),
                ),
              Flexible(
                child: Text(text, style: style, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
