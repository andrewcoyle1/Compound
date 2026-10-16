# program_repository

The signed-in user's mesocycles (`users/{uid}/mesocycles`) and macrocycles
(`users/{uid}/macrocycles`) in Firestore, or in memory in the staging flavor, and
`TrainingSetupService`, which sets up training across the repositories as the Swift app does:
starting a prebuilt program (copy, save, start a macrocycle of one, point the profile at it) and
saving a gym (and making it the usual one).

Writes merge whole documents, as Swift's sync engine does
([`docs/specs/flutter/firestore-contract.md`](../../../docs/specs/flutter/firestore-contract.md)).
