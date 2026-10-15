import 'package:compound/programs/view/macrocycle_detail_page.dart';
import 'package:compound/programs/view/macrocycles_page.dart';
import 'package:compound/programs/view/mesocycle_library_page.dart';
import 'package:compound/programs/view/prebuilt_mesocycle_detail_page.dart';
import 'package:go_router/go_router.dart';

export 'view/macrocycle_detail_page.dart' show MacrocycleDetailPage;
export 'view/macrocycles_page.dart' show MacrocyclesPage;
export 'view/mesocycle_library_page.dart' show MesocycleLibraryPage;
export 'view/prebuilt_mesocycle_detail_page.dart'
    show PrebuiltMesocycleDetailPage;

/// The mesocycle library and the macrocycles, pushed on the Training tab.
final programRoutes = <RouteBase>[
  GoRoute(
    path: MesocycleLibraryPage.path,
    name: MesocycleLibraryPage.name,
    builder: (_, _) => const MesocycleLibraryPage(),
    routes: [
      GoRoute(
        path: PrebuiltMesocycleDetailPage.path,
        name: PrebuiltMesocycleDetailPage.name,
        builder: (_, state) => PrebuiltMesocycleDetailPage(
          mesocycleId:
              state.pathParameters[PrebuiltMesocycleDetailPage.idParameter]!,
        ),
      ),
    ],
  ),
  GoRoute(
    path: MacrocyclesPage.path,
    name: MacrocyclesPage.name,
    builder: (_, _) => const MacrocyclesPage(),
    routes: [
      GoRoute(
        path: MacrocycleDetailPage.path,
        name: MacrocycleDetailPage.name,
        builder: (_, state) => MacrocycleDetailPage(
          macrocycleId: state.pathParameters[MacrocycleDetailPage.idParameter]!,
        ),
      ),
    ],
  ),
];
