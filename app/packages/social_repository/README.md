# social_repository

What users share with each other, ported from the Swift app's social services
(`FirebaseUserQueryService`, `FirebaseWorkoutSessionLikeService`, `FirebaseCommentsService`,
`FirebaseActivityNotificationService`, `FirebaseChallengeService`, `FirebaseInviteService`,
`FirebaseShareService`, `FirebaseReportService`) and the manager and `CoreInteractor` logic around
them. Each method's doc comment cites the Swift lines it follows.

- `SocialRepository` takes `FirebaseFirestore`, a `CallFunction` (`callFirebaseFunction` on
  `FirebaseFunctions.instanceFor(region: 'us-central1')`, for `acceptInvite` and `removeFollower`)
  and the `UserRepository` that writes `following_ids`, `blocked_user_ids` and `username`.
- Reads: followers, people search (handle prefix, then first name), suggestions, profiles by id,
  the following feed (`workout_sessions` collection group, first 30 followed, newest 200), anyone's
  sessions, incoming and sent follow requests, comments, notification pages and new arrivals,
  challenges and standings, shares. Reads that Swift filters by the viewer's block list take the
  viewer. A document that does not decode is skipped and reported to `onDecodeError`.
- Writes complete once Firestore has them locally (`writeLocally`); a server refusal goes to
  `onWriteError`. Documents are written whole with a plain `set`, as Swift does. Reserving a
  username is the exception: it waits for the server, whose answer decides whether it is taken.
- `inMemorySocialRepository` is the same class over an in-memory Firestore seeded with
  `sampleSocial`, Swift's mock social world around `mock_user_123`, with `stagingCallFunction`
  playing the two callables.
- `social_rules.dart`: `Username`, `InviteCode`, `FollowingQueries`, display names and
  `commentNotifications`.

The models are `compound_models`', held to the Firestore contract in
[`docs/specs/flutter/firestore-contract.md`](../../../docs/specs/flutter/firestore-contract.md);
`functions/rules.test.js` checks each write against the rules ("flutter social").
