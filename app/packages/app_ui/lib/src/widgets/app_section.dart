import 'package:app_ui/app_ui.dart';

/// {@template app_section}
/// A group of rows on a card, with an optional header above and footer below:
/// the grouped-list section of the Swift app. Rows are separated by hairlines
/// inset to the text. Outer margins are the screen's job.
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

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final header = this.header;
    final footer = this.footer;
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
                if (index > 0) const Divider(indent: AppSpacing.l),
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
