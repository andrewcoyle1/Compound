# health_repository

Apple Health (HealthKit, iOS) and Health Connect (Android) for the signed-in user, through the
[`health`](https://pub.dev/packages/health) package (MIT), as the Swift app uses Apple Health.

- `HealthPlatform` is what the app needs from the store. `HealthPackagePlatform` implements it on
  `health`'s `Health`, injected through the constructor with the app's own bundle id or package
  name, so samples the app wrote are left out of the imports. `FakeHealthPlatform` holds it in
  memory for staging and tests; `sampleHealthPlatform(now)` seeds it.
- `HealthScope` lists the types each feature asks for, exactly as Swift's `HealthDataScope`.
- `HealthRepository`:
  - availability, permission requests and `needsWorkoutAuthorization`;
  - onboarding's prefill reads (date of birth, sex, height, weight), each asking for its own
    scope first and answering null on any failure;
  - the imports, with Swift's rules: steps (one `healthkit` entry per day, a higher count typed
    here wins), weigh-ins (one entry per day at its lowest reading with that day's latest body
    fat; deleted weigh-ins are cleared with `FieldValue.delete()`, which Swift's merge never
    manages) and food (one `healthkit-nutrition-{day}` meal per day, deleted when the day
    empties). Each recounts its window and writes only what differs. A run that reads nothing
    writes nothing, so revoked access never empties the app;
  - the exports: a weigh-in logged here goes to Health first and its id is saved as
    `healthkit_uuid`; a finished session is saved as a strength training workout.

Writes go through `body_repository` and `nutrition_repository`, which complete offline.
