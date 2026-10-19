import 'package:app_ui/app_ui.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/coach/cubit/coach_cubit.dart';
import 'package:compound/coach/view/coach_chats_page.dart';
import 'package:compound/coach/view/coach_page.dart';
import 'package:go_router/go_router.dart';

/// The coach and its saved chats, over the tabs from any screen. The coach
/// opened by Ask Coach is a full-screen dialog (Swift's sheet) that closes;
/// one opened from the chat list is pushed and goes back. Each takes what
/// it is about as the route's extra.
final coachRoutes = <RouteBase>[
  GoRoute(
    path: CoachPage.path,
    name: CoachPage.name,
    pageBuilder: (_, state) {
      final request = switch (state.extra) {
        final CoachRequest request => request,
        _ => const CoachRequest(),
      };
      return MaterialPage(
        key: state.pageKey,
        fullscreenDialog: request.showsCloseButton,
        child: CoachPage(request: request),
      );
    },
  ),
  GoRoute(
    path: CoachChatsPage.path,
    name: CoachChatsPage.name,
    builder: (_, state) => CoachChatsPage(
      coachContext: switch (state.extra) {
        final CoachContext context => context,
        _ => CoachContext.today,
      },
    ),
  ),
];
