import 'package:app_ui/app_ui.dart';

/// {@template app_search_field}
/// The one search field: a capsule in the `surface` colour, 44 pt tall at
/// the default text size and growing with it, with a search glyph and a
/// clear button.
///
/// The clear button shows while the field has text or focus. It empties the
/// field, reports `''` to [onChanged] and puts the keyboard away, so it also
/// serves as the way out of a search.
///
/// Pass a [controller] or [focusNode] only when the screen needs to read or
/// drive them; otherwise the field keeps its own, starting at
/// [initialValue].
/// {@endtemplate}
class AppSearchField extends StatefulWidget {
  /// {@macro app_search_field}
  const new({
    required this.hint,
    required this.clearLabel,
    required this.onChanged,
    this.controller,
    this.focusNode,
    this.initialValue = '',
    this.autofocus = false,
    super.key,
  });

  /// The placeholder, localized, such as "Search exercises". Screen readers
  /// announce it as the field's label.
  final String hint;

  /// The clear button's spoken label and tooltip, localized.
  final String clearLabel;

  /// Called with the text on every change, and with `''` when cleared.
  final ValueChanged<String> onChanged;

  /// The field's controller, when the screen owns it.
  final TextEditingController? controller;

  /// The field's focus node, when the screen owns it.
  final FocusNode? focusNode;

  /// The text the field opens with when it keeps its own controller.
  final String initialValue;

  /// Whether the field takes focus, and the keyboard opens, on first build.
  final bool autofocus;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  TextEditingController get _controller =>
      widget.controller ??
      (_ownController ??= TextEditingController(text: widget.initialValue));

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void dispose() {
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glyph = AppIconSize.small.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppControlSize.row),
      child: Material(
        color: context.appColors.surface,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.m),
          child: Row(
            spacing: AppSpacing.s,
            children: [
              ExcludeSemantics(
                child: Icon(
                  AppSymbols.search,
                  size: glyph,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  autocorrect: false,
                  textInputAction: TextInputAction.search,
                  onChanged: widget.onChanged,
                  style: AppTextStyles.rowTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    filled: false,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s,
                    ),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: Listenable.merge([_controller, _focusNode]),
                builder: (context, _) =>
                    _controller.text.isEmpty && !_focusNode.hasFocus
                    // Holds the trailing inset the button would leave.
                    ? const SizedBox(width: AppSpacing.xs)
                    : IconButton(
                        tooltip: widget.clearLabel,
                        onPressed: _clear,
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        constraints: const BoxConstraints.tightFor(
                          width: AppControlSize.row,
                          height: AppControlSize.row,
                        ),
                        icon: Icon(
                          AppSymbols.clearText,
                          size: glyph,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
