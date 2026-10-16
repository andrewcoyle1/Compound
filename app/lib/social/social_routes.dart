import 'package:compound/settings/account/username/edit_username_page.dart';
import 'package:compound/social/comments/comments_page.dart';
import 'package:compound/social/followers/people_list_page.dart';
import 'package:compound/social/profile/social_profile_page.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The social screens, over the tabs so the same routes serve the Social
/// tab and the profile cover: a profile and its people lists, someone's
/// workout and its comments, and the username editor.
final socialRoutes = <RouteBase>[
  GoRoute(
    path: SocialProfilePage.path,
    name: SocialProfilePage.name,
    builder: (_, state) => SocialProfilePage(
      userId: state.pathParameters[SocialProfilePage.userIdParameter]!,
      user: switch (state.extra) {
        final UserModel user => user,
        _ => null,
      },
    ),
    routes: [
      GoRoute(
        path: PeopleListPage.path,
        name: PeopleListPage.name,
        builder: (_, state) => PeopleListPage(
          request: switch (state.extra) {
            final PeopleListRequest request => request,
            _ => const PeopleListRequest(
              kind: PeopleListKind.followers,
              people: [],
            ),
          },
        ),
      ),
    ],
  ),
  GoRoute(
    path: SocialNavigation.sessionPath,
    name: SocialNavigation.sessionName,
    builder: (_, state) => WorkoutSessionDetailPage(
      sessionId: state.pathParameters[SocialNavigation.sessionIdParameter]!,
      authorId: state.pathParameters[SocialNavigation.authorIdParameter],
      session: switch (state.extra) {
        final WorkoutSessionModel session => session,
        _ => null,
      },
    ),
    routes: [
      GoRoute(
        path: CommentsPage.path,
        name: CommentsPage.name,
        builder: (_, state) => CommentsPage(
          sessionId: state.pathParameters[SocialNavigation.sessionIdParameter]!,
          authorId: state.pathParameters[SocialNavigation.authorIdParameter]!,
        ),
      ),
    ],
  ),
  GoRoute(
    path: EditUsernamePage.path,
    name: EditUsernamePage.name,
    builder: (_, _) => const EditUsernamePage(),
  ),
];

/// Where the social screens go.
abstract final class SocialNavigation {
  /// Someone's workout: `/sessions/:authorId/:sessionId`.
  static const sessionPath =
      '/sessions/:$authorIdParameter/:$sessionIdParameter';

  /// Its route name.
  static const sessionName = 'socialSession';

  /// The path parameter naming the workout's author.
  static const authorIdParameter = 'authorId';

  /// The path parameter naming the workout.
  static const sessionIdParameter = 'sessionId';

  static Map<String, String> _session(WorkoutSessionModel session) => {
    authorIdParameter: session.authorId,
    sessionIdParameter: session.id,
  };

  /// Opens [user]'s profile.
  static void openProfile(BuildContext context, UserModel user) =>
      context.pushNamed(
        SocialProfilePage.name,
        pathParameters: {SocialProfilePage.userIdParameter: user.userId},
        extra: user,
      );

  /// Opens [session]'s detail.
  static void openSession(BuildContext context, WorkoutSessionModel session) =>
      context.pushNamed(
        sessionName,
        pathParameters: _session(session),
        extra: session,
      );

  /// Opens [session]'s comments.
  static void openComments(BuildContext context, WorkoutSessionModel session) =>
      context.pushNamed(CommentsPage.name, pathParameters: _session(session));

  /// Opens a list of people under [userId]'s profile.
  static void openPeople(
    BuildContext context,
    String userId,
    PeopleListRequest request,
  ) => context.pushNamed(
    PeopleListPage.name,
    pathParameters: {SocialProfilePage.userIdParameter: userId},
    extra: request,
  );

  /// Opens the username editor.
  static void openUsername(BuildContext context) =>
      context.pushNamed(EditUsernamePage.name);
}
