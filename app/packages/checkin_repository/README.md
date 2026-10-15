# checkin_repository

The weekly check-in's data for the signed-in user, and what the app computes from it.

- `FirestoreCheckInRepository` takes `FirebaseFirestore` through its constructor:
  - `users/{uid}/nutrition_strategy_settings/nutrition_strategy_settings` — watched (Swift's
    defaults when absent or unreadable) and saved whole;
  - `users/{uid}/nutrition_day_annotations/{day_key}` — watched in day order; saved in one batch,
    an empty annotation deleting its day;
  - `users/{uid}/logging_break/logging_break` — watched; started and ended;
  - `users/{uid}/check_in_record/check_in_record` — watched; a week marked completed or skipped.

  Every write merges, as Swift's `saveDocument` does. Two fields Swift's merge cannot clear are
  deleted outright instead: `calculation_start_date` when the settings have none, and `end_date`
  when a new break starts. A document that does not decode is skipped and reported to
  `onDecodeError`.
- `InMemoryCheckInRepository` holds the documents as Firestore would, for staging and tests. Seed
  it with `sampleStrategySettings`, `sampleCheckInRecord`, `sampleLoggingBreak` and
  `sampleDayAnnotations`.
- `ExpenditureInputs` assembles `compound_maths`' expenditure engine inputs from the repositories'
  data the way `CoreInteractor+Expenditure.swift` does: the samples, the formula prior, kcal per
  kg, the history (frozen at an open break's start) and the check-in state.
- `CheckInFlow` is the pure half of the Swift `CheckInPresenter`: the reviewed week, the steps,
  the list rows and the annotations each list step saves.

The models are `compound_models'`, held to the Firestore contract in
[`docs/specs/flutter/firestore-contract.md`](../../../docs/specs/flutter/firestore-contract.md).
