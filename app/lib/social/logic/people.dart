import 'package:compound_models/compound_models.dart';
import 'package:social_repository/social_repository.dart';

/// What the follow button offers for one person, from the reader's side
/// (Swift `FollowState`).
enum FollowState {
  /// Not following: a tap follows a public profile and requests a private
  /// one.
  follow,

  /// Following.
  following,

  /// A request to a private profile waits on its owner: a tap cancels it.
  requested,
}

/// [viewer]'s button for [userId]. Following wins over a request, so a
/// request the owner accepted reads as following the moment the function's
/// write reaches the viewer's profile (`FollowInteractor.followState`).
FollowState followStateOf(
  UserModel? viewer,
  Set<String> sentRequestIds,
  String userId,
) {
  if (viewer?.followingIds?.contains(userId) ?? false) {
    return FollowState.following;
  }
  if (sentRequestIds.contains(userId)) return FollowState.requested;
  return FollowState.follow;
}

/// Whether [viewer] has blocked [userId] (`UserModel.hasBlocked`).
bool hasBlocked(UserModel? viewer, String userId) =>
    viewer?.blockedUserIds?.contains(userId) ?? false;

/// The people [viewer] follows who follow them back, less anyone they
/// blocked: who a challenge or a share can go to, since it lands in the
/// other person's own screens (`CreateChallengePresenter.candidates`,
/// `ShareToFollowerPresenter.recipients`).
List<UserModel> mutualsOf(UserModel viewer, List<UserModel> following) => [
  for (final user in following)
    if (user.userId != viewer.userId &&
        !hasBlocked(viewer, user.userId) &&
        (user.followingIds?.contains(viewer.userId) ?? false))
      user,
];

/// The name a list shows for [user]: full name, else first name, else null
/// (`UserRowView.displayName`).
String? listNameOf(UserModel user) => fullNameOf(user) ?? firstNameOf(user);

/// The name the circle shows (`CircleMember.name`): the display name, else
/// the first name, else the full name.
String? commonNameOf(UserModel user) {
  final display = user.displayName;
  if (display != null && display.isNotEmpty) return display;
  return firstNameOf(user) ?? fullNameOf(user);
}
