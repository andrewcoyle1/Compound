import 'package:compound/programs/view/create_mesocycle_pages.dart';
import 'package:compound/programs/view/import_program_page.dart';
import 'package:compound/programs/view/macrocycle_detail_page.dart';
import 'package:compound/programs/view/macrocycles_page.dart';
import 'package:compound/programs/view/mesocycle_design_page.dart';
import 'package:compound/programs/view/mesocycle_library_page.dart';
import 'package:compound/programs/view/prebuilt_mesocycle_detail_page.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

export 'view/create_mesocycle_pages.dart' show NameMesocyclePage;
export 'view/import_program_page.dart' show ImportProgramPage;
export 'view/macrocycle_detail_page.dart' show MacrocycleDetailPage;
export 'view/macrocycles_page.dart' show MacrocyclesPage;
export 'view/mesocycle_design_page.dart' show MesocycleDesignPage;
export 'view/mesocycle_library_page.dart' show MesocycleLibraryPage;
export 'view/prebuilt_mesocycle_detail_page.dart'
    show PrebuiltMesocycleDetailPage;

/// A page that rises like the Swift app's sheet or cover.
Page<void> _sheet(GoRouterState state, Widget child) =>
    MaterialPage(key: state.pageKey, fullscreenDialog: true, child: child);

/// The mesocycle library and the macrocycles, pushed on the Training tab,
/// and the mesocycle editor, the create flow and the importer over it.
final programRoutes = <RouteBase>[
  GoRoute(
    path: NameMesocyclePage.path,
    name: NameMesocyclePage.name,
    pageBuilder: (_, state) => _sheet(state, const NameMesocyclePage()),
    routes: [
      GoRoute(
        path: MesocycleIconPage.path,
        name: MesocycleIconPage.name,
        builder: (_, state) => MesocycleIconPage(
          mesocycleName:
              state.uri.queryParameters[MesocycleIconPage.nameParameter] ?? '',
        ),
      ),
      GoRoute(
        path: MesocycleDesignPage.createPath,
        name: MesocycleDesignPage.createName,
        builder: (_, state) => MesocycleDesignPage(
          draft: switch (state.extra) {
            final Mesocycle draft => draft,
            _ => null,
          },
        ),
      ),
    ],
  ),
  GoRoute(
    path: MesocycleDesignPage.editPath,
    name: MesocycleDesignPage.editName,
    pageBuilder: (_, state) => _sheet(
      state,
      MesocycleDesignPage(
        mesocycleId: state.pathParameters[MesocycleDesignPage.idParameter],
      ),
    ),
  ),
  GoRoute(
    path: ImportProgramPage.path,
    name: ImportProgramPage.name,
    pageBuilder: (_, state) => _sheet(state, const ImportProgramPage()),
  ),
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
