import 'package:app_ui/app_ui.dart';

/// {@template app_section}
/// A group of rows on a card, with an optional header above and footer below:
/// the grouped-list section of the Swift app. Rows are separated by hairlines
/// inset to the text: past the leading icon or thumbnail of the `app_ui` row
/// above, 16 pt in otherwise. Outer margins are the screen's job.
///
/// [trailing] sits at the header's trailing edge: an [AppChip] with
/// `onPressed` for an action such as "See All", "New" or "Hide", or a plain
/// [Text] for a note such as "Required" or a count, which takes the footer's
/// small secondary style.
///
/// With [grouped] false the children are not put on one card: they stand
/// apart, [AppSpacing.m] between them, under the same header. Use it for a
/// list of cards of their own, such as a feed's workouts.
/// {@endtemplate}
class AppSection extends StatelessWidget {
  /// {@macro app_section}
  const new({
    required this.children,
    this.header,
    this.trailing,
    this.footer,
    this.grouped = true,
    super.key,
  });

  /// The rows, usually [AppListRow]s.
  final List<Widget> children;

  /// A title above the card, announced as a heading.
  final String? header;

  /// A note or small action at the header's trailing edge.
  final Widget? trailing;

  /// A note below the card.
  final String? footer;

  /// Whether the children share one card, with dividers between them.
  final bool grouped;

  /// Where the hairline under [row] starts: past the leading icon or
  /// thumbnail of an `app_ui` row, 16 pt in otherwise.
  static double dividerIndent(Widget row, TextScaler scaler) => switch (row) {
    AppListRow(:final icon, :final thumbnail) ||
    AppListRowButton(
      :final icon,
      :final thumbnail,
    ) => AppListRow.textInset(scaler, icon: icon, thumbnail: thumbnail),
    AppListRowToggle(:final icon) => AppListRow.textInset(scaler, icon: icon),
    AppFeatureRow() => AppFeatureRow.textInset(scaler),
    _ => AppSpacing.l,
  };

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final header = this.header;
    final footer = this.footer;
    final trailing = this.trailing;
    final note = AppTextStyles.label.copyWith(color: secondary);
    final scaler = MediaQuery.textScalerOf(context);
    const inset = EdgeInsets.symmetric(horizontal: AppSpacing.l);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.s,
      children: [
        if (header != null || trailing != null)
          Padding(
            padding: inset,
            child: Row(
              spacing: AppSpacing.s,
              children: [
                Expanded(
                  child: header == null
                      ? const SizedBox.shrink()
                      : Semantics(
                          header: true,
                          child: Text(
                            header,
                            style: AppTextStyles.sectionTitle.copyWith(
                              color: secondary,
                            ),
                          ),
                        ),
                ),
                if (trailing != null)
                  DefaultTextStyle.merge(style: note, child: trailing),
              ],
            ),
          ),
        if (grouped)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, child) in children.indexed) ...[
                  if (index > 0)
                    Divider(indent: dividerIndent(children[index - 1], scaler)),
                  child,
                ],
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.m,
            children: children,
          ),
        if (footer != null)
          Padding(
            padding: inset,
            child: Text(footer, style: note),
          ),
      ],
    );
  }
}
