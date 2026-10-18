import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/shell/app_tab.dart';

/// A tab's root until its screen is ported: its title, the profile button
/// every tab carries, and a "coming soon" empty state.
class TabPlaceholderPage extends StatelessWidget {
  const new({required this.tab, super.key});

  /// The tab this stands in for.
  final AppTab tab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppScaffold(
      appBar: AppBar(
        title: Text(tab.label(l10n)),
        actions: const [ProfileButton()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.s,
            children: [
              Icon(
                tab.icon,
                size: AppIconSize.hero.of(context),
                color: secondary,
              ),
              Text(
                l10n.tabComingSoonTitle,
                style: AppTextStyles.sectionTitle,
                textAlign: TextAlign.center,
              ),
              Text(
                l10n.tabComingSoonMessage,
                style: AppTextStyles.rowDetail.copyWith(color: secondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
