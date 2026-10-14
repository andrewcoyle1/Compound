import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:go_router/go_router.dart';

/// The Progress tab's root, for now only the way into the weight screens.
/// The overview cards (Swift `AnalyticsView`) replace this in M2-8.
class ProgressPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tint = context.appColors.scaleWeight;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabProgress),
        actions: const [ProfileButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            AppSection(
              header: l10n.progressBodyHeader,
              children: [
                for (final metric in WeightMetric.values)
                  AppListRowButton(
                    title: metric.title(l10n),
                    icon: switch (metric) {
                      WeightMetric.scaleWeight => AppSymbols.scaleWeight,
                      WeightMetric.weightTrend => AppSymbols.analytics,
                    },
                    tint: tint,
                    onPressed: () => context.goNamed(metric.name),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
