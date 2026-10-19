import 'package:app_ui/app_ui.dart';

/// {@template app_section}
/// A group of rows on a card, with an optional header above and footer below:
/// the grouped-list section of the Swift app. Rows are separated by hairlines
/// inset to the text: past the leading icon or thumbnail of the `app_ui` row
/// above, 16 pt in otherwise. Outer margins are the screen's job.
/// {@endtemplate}
class AppSection extends StatelessWidget {
  /// {@macro app_section}
  const new({required this.children, this.header, this.footer, super.key});

  /// The rows, usually [AppListRow]s.
  final List<Widget> children;

  /// A title above the card, announced as a heading.
  final String? header;

  /// A note below the card.
  final String? footer;

  static double _dividerIndent(Widget row, TextScaler scaler) => switch (row) {
    AppListRow(:final icon, :final thumbnail) ||
    AppListRowButton(
      :final icon,
      :final thumbnail,
    ) => AppListRow.textInset(scaler, icon: icon, thumbnail: thumbnail),
    AppListRowToggle(:final icon) => AppListRow.textInset(scaler, icon: icon),
    _ => AppSpacing.l,
  };

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final header = this.header;
    final footer = this.footer;
    final scaler = MediaQuery.textScalerOf(context);
    const inset = EdgeInsets.symmetric(horizontal: AppSpacing.l);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.s,
      children: [
        if (header != null)
          Padding(
            padding: inset,
            child: Semantics(
              header: true,
              child: Text(
                header,
                style: AppTextStyles.sectionTitle.copyWith(color: secondary),
              ),
            ),
          ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0)
                  Divider(indent: _dividerIndent(children[index - 1], scaler)),
                child,
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: inset,
            child: Text(
              footer,
              style: AppTextStyles.label.copyWith(color: secondary),
            ),
          ),
      ],
    );
  }
}
