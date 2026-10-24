import 'package:app_ui/app_ui.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/coach/cubit/coach_access_cubit.dart';
import 'package:compound/coach/view/coach_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The one way into the coach from a screen (Swift `AskCoachToolbarItem`),
/// so every entry point looks and reads the same. Opens the coach about
/// [coachContext]; consent is the coach's to check. Shown only while the
/// coach is on: it is premium only, and Settings can turn it off.
class AskCoachButton extends StatelessWidget {
  const new(this.coachContext, {super.key});

  final CoachContext coachContext;

  @override
  Widget build(BuildContext context) {
    final on = context.select<CoachAccessCubit, bool>(
      (cubit) => cubit.state.isOn,
    );
    if (!on) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Semantics(
      hint: l10n.coachAskCoachHint,
      child: AppToolbarButton(
        icon: AppSymbols.coach,
        semanticLabel: l10n.coachAskCoach,
        onPressed: () => CoachPage.open(context, coachContext),
      ),
    );
  }
}
