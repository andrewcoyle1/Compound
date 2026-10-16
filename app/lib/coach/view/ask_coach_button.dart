import 'package:app_ui/app_ui.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/coach/view/coach_page.dart';
import 'package:compound/l10n/l10n.dart';

/// The one way into the coach from a screen (Swift `AskCoachToolbarItem`),
/// so every entry point looks and reads the same. Opens the coach about
/// [coachContext]; premium and consent are the coach's to check.
class AskCoachButton extends StatelessWidget {
  const new(this.coachContext, {super.key});

  final CoachContext coachContext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      hint: l10n.coachAskCoachHint,
      child: IconButton(
        icon: const Icon(AppSymbols.coach),
        tooltip: l10n.coachAskCoach,
        onPressed: () => CoachPage.open(context, coachContext),
      ),
    );
  }
}
