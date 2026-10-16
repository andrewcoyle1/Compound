import 'package:compound/sharing/view/shared_item_page.dart';
import 'package:go_router/go_router.dart';

/// A shared template or mesocycle, over the tabs as the other social
/// screens are.
final sharingRoutes = <RouteBase>[
  GoRoute(
    path: SharedItemPage.path,
    name: SharedItemPage.name,
    builder: (_, state) => SharedItemPage(
      shareId: state.pathParameters[SharedItemPage.idParameter]!,
      request: switch (state.extra) {
        final SharedItemRequest request => request,
        _ => null,
      },
    ),
  ),
];
