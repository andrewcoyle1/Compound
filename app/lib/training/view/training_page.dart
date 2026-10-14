import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/workout_history/view/workout_history_page.dart';
import 'package:go_router/go_router.dart';

/// The Training tab's root. For now only the Library's way into the workout
/// history; the schedule, the rest of the Library and search come with
/// programs and the tracker.
class TrainingPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabTraining),
        actions: const [ProfileButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            AppSection(
              header: l10n.trainingLibraryHeader,
              children: [
                AppListRowButton(
                  title: l10n.workoutHistoryTitle,
                  icon: AppSymbols.history,
                  onPressed: () => context.goNamed(WorkoutHistoryPage.name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
