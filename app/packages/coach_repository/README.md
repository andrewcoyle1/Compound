# coach_repository

The AI coach (Swift `CoachManager`, `CoachService`, `CoachModels`). No UI; premium is the
caller's to check (`purchases_repository`).

- `CoachRepository` takes `FirebaseFirestore`, a `UserRepository` and a `CoachChatCall`:
  `firebaseCoachChat(FirebaseFunctions.instanceFor(region: coachFunctionsRegion))`
  (`europe-west4`, 120 s timeout), or `stagingCoachChat` in staging.
- `send(message, chatId:, context:)` streams `CoachText` chunks, then `CoachFinished` with the
  chat id, the whole text and `remainingToday`. Failures are `CoachException`s:
  `consentRequired`, `premiumRequired`, `dailyLimitReached`, `tooManyAtOnce`, `unavailable`,
  `failed`.
- cloud_functions 6.5's stream drops a refusal's code (Android ends the stream, iOS says
  `unknown`), so without a result or a code the message is sent once more without streaming.
- `watchChats(uid)` reads `users/{uid}/coach_chats` newest first; `deleteChat` deletes one.
  Chats are only written by the function, and are under the Firestore contract (`coach_chat`).
- `watchConsent`, `giveConsent` (`coach_consent: true` and `coach_consent_at`) and
  `withdrawConsent` (`coach_consent: false`, then every chat deleted) go through
  `UserRepository.mergePrivateSettings`.
- `inMemoryCoachRepository(firestore:, users:, now:)` is the same class over the in-memory
  Firestore it is given (`FakeFirebaseFirestore`, a dev dependency, so release builds never carry
  it), with the sample chat; its coach refuses without consent and saves each exchange as the function does.
