# strava_repository

Strava without UI (Swift `StravaManager`, `StravaStrengthFile`, `StravaExerciseType`,
`StravaOffer`). The tokens live on the server; the app holds a short-lived access token in memory.

- `StravaRepository` takes a `FirebaseFirestore` (imported activities, read only), a `StravaApi`,
  the `WorkoutSessionRepository` (queued sessions are read from it, and each is stamped with
  `updateStravaActivityId`), a `StravaAccountStore`, Strava's client id and an `uploadContext`
  (the exercise library and the user's units).
  - `signIn(uid)` loads the account's state on this device, refreshes the connection and sends
    the queue. `signOut()` forgets it here; the connection stays with the account.
  - `connect(authorizer)` opens Strava's consent page through a `StravaAuthorizer` (the UI slice
    implements it with a web authentication session; redirect `compoundstrava://localhost/exchange_token`),
    refuses a grant without `activity:write`, and exchanges the code through `stravaConnect`.
  - `disconnect()`, `refreshConnection()`, `watchAthlete()`.
  - `queueUpload(session)` after each finish; `queueBackfill()` for past workouts, then
    `syncPendingUploads()`. A workout goes in Strava's JSON strength format with a set summary in
    its description, `external_id` `compound-<session id>`, so a second upload is a duplicate.
  - `pushEdit(session)` sends an edited name and description to the activity;
    `uploadTestActivity()` checks the connection.
  - `watchImportedActivities(uid)`: the owner's own screens only, per Strava's terms.
- `RemoteStravaApi(callFunction: callStravaFunction(FirebaseFunctions.instanceFor(region:
  stravaFunctionsRegion)), client: http.Client())`. Failures are `StravaException`s.
- `FileStravaAccountStore(directory)` keeps each account's athlete, queue and offer answer.
- Staging: `FakeStravaApi(firestore: fakeFirestore, uid: …, activities:
  sampleStravaActivities(now))`, `FakeStravaAuthorizer()` and `InMemoryStravaAccountStore()`, with
  the same fake Firestore passed to the repository.
- Rules for screens: `shouldOfferStrava`, `stravaActivityLink`, `StravaTotals.of`.
