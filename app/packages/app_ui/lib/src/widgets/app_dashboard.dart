import 'package:app_ui/app_ui.dart';

/// {@template app_dashboard}
/// A tab root's sections (Swift's `Dashboard`): one scrolling column on a
/// phone, and from [AppContentWidth.twoColumns] up the same sections in two
/// columns, so a wide window is not one long strip down the middle.
/// Sections alternate left and right, so reading order runs across then
/// down.
///
/// Give its screen a [AppContentWidth.dashboard] column through
/// [AppScaffold.maxWidth].
/// {@endtemplate}
class AppDashboard extends StatelessWidget {
  /// {@macro app_dashboard}
  const new({required this.sections, super.key});

  /// The sections, usually [AppSection]s and cards, without spacers.
  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.all(AppSpacing.l);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppContentWidth.twoColumns) {
          return ListView(
            padding: padding,
            children: [
              for (final (index, section) in sections.indexed) ...[
                if (index > 0) const SizedBox(height: AppSpacing.xl),
                section,
              ],
            ],
          );
        }
        return SingleChildScrollView(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.l,
            children: [
              for (final column in [0, 1])
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpacing.xl,
                    children: [
                      for (final (index, section) in sections.indexed)
                        if (index.isEven == (column == 0)) section,
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
