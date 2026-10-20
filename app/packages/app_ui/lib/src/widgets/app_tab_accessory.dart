import 'package:app_ui/app_ui.dart';

/// {@template app_tab_accessory}
/// A bar in the tab bar's dock, above the tabs: the workout under way or
/// the unlogged meal (Swift's tab view bottom accessory). A card like the
/// tab bar's own, the whole of [child] one button announced as
/// [semanticLabel], with [trailing] (Skip Rest) beside it rather than in it,
/// so a screen reader reaches it.
///
/// It brings its own gap to the tab bar below it, so a bar that hides itself
/// leaves no space behind. Pass it as [AppTabBar.accessory].
/// {@endtemplate}
class AppTabAccessory extends StatelessWidget {
  /// {@macro app_tab_accessory}
  const new({
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.trailing,
    super.key,
  });

  /// What a screen reader announces for the bar's button.
  final String semanticLabel;

  /// Called when the bar is tapped anywhere but [trailing].
  final VoidCallback onTap;

  /// The bar's content, usually a row of an icon, two lines and a value.
  final Widget child;

  /// A button beside the content, outside its tap target.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: semanticLabel,
                excludeSemantics: true,
                child: InkWell(
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppControlSize.row,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.l,
                        vertical: AppSpacing.s,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
