import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/view/diet_setup_page.dart';
import 'package:compound/onboarding/view/goal_setup_page.dart';
import 'package:go_router/go_router.dart';

/// Setting or changing the weight goal after onboarding (Swift
/// `showWeightGoalFlow`): over the tabs, as Swift's sheet. `?edit=1` edits
/// the running goal; without it a new goal is started.
abstract final class WeightGoalRoute {
  static const path = '/weight-goal';
  static const name = 'weightGoal';
  static const editParameter = 'edit';
}

/// Creating or rebuilding the diet plan after onboarding (Swift
/// `showPreferredDietView(isFromSettings: true)`), pushed as Swift does.
abstract final class DietPlanRoute {
  static const path = '/diet-plan';
  static const name = 'dietPlan';
}

/// The goal and diet flows opened after onboarding, at the router's root
/// so Settings and Progress share them.
final goalEditingRoutes = <RouteBase>[
  GoRoute(
    path: WeightGoalRoute.path,
    name: WeightGoalRoute.name,
    pageBuilder: (_, state) => MaterialPage(
      key: state.pageKey,
      fullscreenDialog: true,
      child: GoalSetupPage(
        isStandalone: true,
        editsCurrentGoal:
            state.uri.queryParameters[WeightGoalRoute.editParameter] == '1',
      ),
    ),
  ),
  GoRoute(
    path: DietPlanRoute.path,
    name: DietPlanRoute.name,
    builder: (_, _) => const DietSetupPage(isFromSettings: true),
  ),
];

/// Opens the weight goal flow for [goal], the user's current one (Swift
/// `WeightGoalChoices`): with a goal running, the choice is to edit it
/// (where it started stays) or to start a new one from today's weight;
/// otherwise a new goal is set straight away.
Future<void> openWeightGoal(BuildContext context, WeightGoal? goal) async {
  void open({required bool edit}) => unawaited(
    context.pushNamed<void>(
      WeightGoalRoute.name,
      queryParameters: edit ? {WeightGoalRoute.editParameter: '1'} : {},
    ),
  );
  if (goal == null || goal.status != GoalStatus.active) {
    open(edit: false);
    return;
  }
  final l10n = context.l10n;
  final edit = await showAppDialog<bool>(
    context: context,
    title: l10n.weightGoalTitle,
    message: l10n.weightGoalChoicesMessage,
    actions: [
      AppDialogAction(label: l10n.weightGoalEdit, value: true),
      AppDialogAction(label: l10n.weightGoalStartNew, value: false),
      AppDialogAction(label: l10n.weightGoalCancel, role: AppDialogRole.cancel),
    ],
  );
  if (edit == null || !context.mounted) return;
  open(edit: edit);
}

/// Opens the diet questions to create or rebuild the plan.
void openDietPlan(BuildContext context) =>
    unawaited(context.pushNamed<void>(DietPlanRoute.name));
