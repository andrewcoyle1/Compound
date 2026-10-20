import 'package:app_ui/app_ui.dart';
import 'package:compound/workout_editor/view/workout_wizard_pages.dart';
import 'package:go_router/go_router.dart';

/// The workout wizard, new or editing, over the Training tab as the Swift
/// app's full-screen cover. Each page carries its route name, which the
/// wizard's Save pops back to.
final workoutEditorRoutes = <RouteBase>[
  GoRoute(
    path: NameWorkoutPage.createPath,
    name: NameWorkoutPage.createName,
    pageBuilder: (_, state) => MaterialPage(
      key: state.pageKey,
      name: NameWorkoutPage.createName,
      fullscreenDialog: true,
      child: const NameWorkoutPage(),
    ),
  ),
  GoRoute(
    path: NameWorkoutPage.editPath,
    name: NameWorkoutPage.editName,
    pageBuilder: (_, state) => MaterialPage(
      key: state.pageKey,
      name: NameWorkoutPage.editName,
      fullscreenDialog: true,
      child: NameWorkoutPage(
        workoutId: state.pathParameters[NameWorkoutPage.idParameter],
      ),
    ),
  ),
];
