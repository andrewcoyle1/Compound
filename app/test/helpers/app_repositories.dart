import 'package:coach_repository/coach_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:social_repository/social_repository.dart';
import 'package:user_repository/user_repository.dart';

/// An empty social world, for an `App` test that never opens Social.
SocialRepository emptySocialRepository() => SocialRepository(
  firestore: FakeFirebaseFirestore(),
  callFunction: (_, _) async => null,
  users: InMemoryUserRepository(),
);

/// A coach that answers nothing, for an `App` test that never opens it.
CoachRepository silentCoachRepository() => CoachRepository(
  firestore: FakeFirebaseFirestore(),
  users: InMemoryUserRepository(),
  coachChat: (_, {chatId, context, regenerate = false}) =>
      Stream.error(const CoachException(CoachFailure.unavailable)),
);
