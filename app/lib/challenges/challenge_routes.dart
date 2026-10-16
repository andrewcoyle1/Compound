import 'package:compound/challenges/view/challenge_detail_page.dart';
import 'package:compound/challenges/view/create_challenge_page.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The challenge screens, over the tabs like the other social screens:
/// New Challenge as a full-screen dialog (Swift's sheet), and a
/// challenge's standings.
final challengeRoutes = <RouteBase>[
  GoRoute(
    path: CreateChallengePage.path,
    name: CreateChallengePage.name,
    pageBuilder: (_, state) => MaterialPage(
      key: state.pageKey,
      fullscreenDialog: true,
      child: const CreateChallengePage(),
    ),
  ),
  GoRoute(
    path: ChallengeDetailPage.path,
    name: ChallengeDetailPage.name,
    builder: (_, state) => ChallengeDetailPage(
      challengeId: state.pathParameters[ChallengeDetailPage.idParameter]!,
      challenge: switch (state.extra) {
        final ChallengeModel challenge => challenge,
        _ => null,
      },
    ),
  ),
];

/// Where the challenge screens go.
abstract final class ChallengeNavigation {
  /// Opens New Challenge.
  static void openNew(BuildContext context) =>
      context.pushNamed(CreateChallengePage.name);

  /// Opens [challenge]'s standings.
  static void open(BuildContext context, ChallengeModel challenge) =>
      context.pushNamed(
        ChallengeDetailPage.name,
        pathParameters: {ChallengeDetailPage.idParameter: challenge.id},
        extra: challenge,
      );
}
