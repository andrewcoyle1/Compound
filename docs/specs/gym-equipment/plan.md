# Gym equipment data structures: finish and polish

## Context

The owner wants the gym profile and its equipment models finished before the exercise-variation
work starts (that comes next, as its own plan). Prompted by a real machine the app cannot describe:
a pin stack with 7 kg plates plus two 2 kg toggle weights. Investigation (8 Oct 2026) found:

- **Three resolvers disagree.** The keyboard's ± (`WeightStepper`) filters active ranges and falls
  back to 2.5 kg; prefill/warm-up rounding (`WorkoutSessionModel.roundWeightToEquipmentIncrement`)
  and progression (`equipmentWeightRange` → `WeightRoundingRule`) ignore `isActive` and fall back
  to the built-in catalogue's machine. A kg user on the default lat pulldown steps 2.27 kg but is
  prescribed 5 kg jumps. `WorkoutSessionModel.swift:426` divides by an unguarded increment.
- **Machines are one even grid** (min, max, increment); every default starts at 0, which no stack
  can be set to. No add-ons, no irregular stacks.
- **Plate-loaded machines assume two sleeves** (step = 2 × smallest plate): T-bar, belt squat, sled,
  hip thrust step twice too far. The plate-loaded editor's unit picker never writes `unit` (bug).
- **Plates** are found by `id.hasSuffix("plates")`; no counts, no collars.
- **Bands:** one at a time, and the band chosen on the keyboard is never saved to the set
  (`SetKeyboardPresenter.bandIndex` is local; the set's weight is cleared).
- **Identity is the catalogue type**: a gym cannot hold two lat pulldowns or its own machine, and
  `GymProfileModel.equipmentIndex` uses `uniqueKeysWithValues`, which traps on a duplicate.
- **Decoding is brittle:** every gym type uses synthesized `Codable`. A missing key or a new
  non-optional field fails the whole profile, which Firestore's listener then skips silently and
  the local cache drops along with every other profile. No legacy-decode tests exist.
- Pin and cable editors are ~420 lines of rename-only copies; mocks duplicate the defaults.

Owner's scope decision (8 Oct 2026): the three core changes plus custom & duplicate machines,
irregular stacks, plate counts & collars, and combined bands.

## Decisions

- **Wire format stays.** Nested keys remain camelCase; every new field decodes with a default, so
  no migration script and no Firestore rules change. New-field defaults for catalogue items come
  from the catalogue entry with the same type id (a stored T-bar decodes `sleeves: 1`), else a
  constant.
- **One resolver.** `WeightStepper.steps(for:profile:unit:)` is the single answer to "what can this
  exercise weigh in this gym". Rounding, prefill, warm-ups and progression all round to what it
  allows. Its fallback (gym truth, then 2.5 kg / 5 lb) wins over the catalogue fallback.
- **Stacks** become one shared value type for cable and pin-loaded machines. Allowed loads =
  each pin position ⊕ every subset of add-ons, sorted and de-duplicated, fed to the existing
  `WeightStep.Kind.list`. A three-position lever is two equal toggles. Irregular stacks are an
  optional explicit list of pin weights that replaces the min/max/increment grid.
- **Identity:** every gym item gains `typeId` (the catalogue type it is; decodes as its `id`).
  Exercises keep referencing types; `equipmentRef` uses `typeId`; the resolver takes the first
  active instance of the type. Choosing a specific instance in a session belongs to the
  variation plan. Custom and duplicate items are limited to the three machine kinds.
- **Bands** are recorded on the set as names; a variation may combine a load (bar) with bands.

## Work packages

Branch `feature/gym-equipment`, cut from `development` at `090e3868` (PR #73 merged 8 Oct 2026). Same workflow as
programs: one Opus agent per package in its own worktree, PR into the feature branch, I gate (lint,
three builds, full unit bundle, named suites) and squash-merge. Plan and status log go in
`docs/specs/gym-equipment/plan.md`. Order: G1 → G2 → (G3 ∥ G4) → (G5 ∥ G6).

### G1 — Tolerant decoding (no behaviour change)
- Commit a fixture first: today's `GymProfileModel.mock` and a default profile, encoded, as
  `CompoundUnitTests/Fixtures/gym-profile-v1.json`.
- `GymProfileModel`: custom `init(from:)`; each array `decodeIfPresent ?? catalogue default`; a
  small lossy-array helper so one undecodable item is skipped, not the gym. Pattern to copy:
  `WorkoutExerciseModel.init(from:)` (`Managers/Training/WorkoutSession/Models/WorkoutExerciseModel.swift:91`).
- Each equipment struct gets an `init(from:)` (fields `decodeIfPresent` with defaults; ids and names
  still required). Files under `Compound/Managers/Training/GymProfile/Model/`.
- Merge on decode: catalogue types the stored profile lacks are appended inactive, so catalogue
  growth reaches existing gyms (items cannot be deleted, so nothing is resurrected).
- `equipmentIndex`: `Dictionary(_:uniquingKeysWith:)` keeping the first.
- Tests (`GymProfileManagerTests` or new `GymProfileDecodingTests`): the v1 fixture decodes; a
  profile missing a key, an item with an unknown extra field, and one corrupt item all decode.

### G2 — One resolver
- `WeightRoundingRule` wraps a `WeightStep` instead of min/max/increment: `round` = nearest allowed
  value (`.list` nearest; `.increment` grid clamp; plate-loaded via `PlateCalculator.nearestLoadableKg`);
  `minimumIncrementKg` = smallest positive gap between allowed values (or the grid step).
- Delete `WorkoutSessionModel.roundWeightToEquipmentIncrement`'s machine logic, both
  `resolveRange`, `WorkoutSessionModel+Prefill.equipmentWeightRange` and `preferredRange`; prefill
  (`roundWeightForLogging`) and warm-ups (`+WarmupSets.roundWarmupWeight`) call the rule.
- Zero-increment guard lives in `WeightStepper.ranged` (already) and nowhere else.
- Tests (`WeightStepperTests`, `ActiveWorkoutStateTests` rounding section): inactive range ignored;
  kg user with kg range inactive / lb active; default-range fallback; machine missing from the gym →
  2.5 kg; for every case, rounding lands on a value the keyboard can step to.

### G3 — Stacks
- New `Model/WeightStack/WeightStack.swift`: id, name, minWeight, maxWeight, increment, unit,
  isActive (existing keys) + `addOns: [Double] = []` + `weights: [Double]? = nil` (irregular
  stack) + `func loads() -> [Double]`. Positions start at the increment when a stored min is 0.
  `PinLoadedMachineRange` and `CableMachineRange` become typealiases of it; the `WeightRange`
  protocol goes.
- `WeightStepper.ranged` returns `.list(loads)` for stacks with add-ons or an explicit list, the
  grid otherwise. A stack breakdown helper ("Pin 21 + 2 kg") beside `PlateCalculator`, shown where
  the set row and keyboard show "Per side" (`SetTrackerRowPresenter.swift:305`, `SetKeyboardView.swift:110`).
- One generic editor replaces the pin/cable copies: `EditStackMachine` + `AddWeightStack` over a
  small protocol both machine structs adopt; `EditWeightRange` gains add-on rows and an
  "Uneven stack" list. Delete `EditCableMachine`, `AddCableMachineRange`, `AddPinLoadedMachineRange`
  and merge their tests into the generic ones (`GymMachineEditorPresenterTests`,
  `GymEquipmentAdderPresenterTests`). Fix: deleting the default range re-points `defaultRangeId`.
- Catalogue: stack minimums become the first pin (5 lb / 2.5 kg). Gym rows summarise add-ons.
- Tests: 7 kg × n with [2, 2] → 7, 9, 11, 14, …; explicit list; min 0 legacy; progression's
  smallest step is 2 kg on that stack; breakdown text.

### G4 — Plate-loaded machines, plates, collars
- `PlateLoadedMachine.sleeves: Int` (1 or 2; catalogue sets 1 for the T-bar rows, both belt
  squats, sled, hip thrusts, reverse hypers, plate-loaded single cable). Step = sleeves × smallest
  plate; plate calculator loads `(total − base) / sleeves`.
- `FreeWeights.isPlates: Bool` (decodes as `id.hasSuffix("plates")`) replaces the suffix check in
  `WeightStepper.availablePlates`; `FreeWeightsAvailable.count: Int?` (nil = unlimited).
- `PlateCalculator` takes `[Plate]` (weight, per-sleeve cap = count / sleeves); greedy respects caps.
  `WeightStep.plates` and `WeightRoundingRule.PlateLoading` carry it.
- `LoadableBars.collarWeight: Double = 0` (per collar, always on): effective base = bar +
  2 × collar; chip reads "Bar 20 kg + collars".
- Editors: plate-loaded sleeves picker and the unit fix (`EditPlateLoadedMachinePresenter`); plate
  count field in `AddFreeWeight`/`EditFreeWeight` when the item is plates; collar field on
  `EditLoadableBar`.
- Tests: single-sleeve step; capped greedy (only two 20s → falls to 15s); collars in nearest
  loadable; plate-loaded unit picker persists.

### G5 — Custom and duplicate machines
- `typeId` on every item (G1 decoded it as `id`); `GymEquipmentItem.equipmentRef` uses it.
  `AnyEquipment` keeps `ref` (type) and gets an instance id for `Identifiable`.
- `WeightStepper.step(for:)` matches `typeId`, first active instance.
- Gym profile screen, machine sections: row menu **Duplicate** (copy, new UUID id, same `typeId`,
  name "<name> 2", editable) and **Add Machine…** (kind, name, "Works as" a catalogue type of
  that kind, optional; without one `typeId == id`). Custom items can be renamed and deleted;
  catalogue items still cannot be deleted.
- Exercise creation's equipment list (`ExerciseEquipmentInteractor.allEquipmentTypes`) adds custom
  items without a "Works as" from the user's gyms, so they can be used.
- Tests: duplicate resolves to first active; deactivate the first → second used; index with
  duplicates does not trap; custom item appears in the creation list; decode keeps `typeId`.

### G6 — Combined bands
- `WorkoutSetModel.bands: [String]?` (decodeIfPresent); `volumeKg` unchanged (bands carry no kg).
- `WeightStep` gains `bands: [String]` alongside its kind, so a variation with a bar and bands
  offers both; band-only keeps an empty weight.
- Keyboard: band chips, multi-select, writing `set.bands` (replaces `bandIndex` cycling in
  `SetKeyboardPresenter`); ± still steps the load.
- Set row, previous-values column and session detail show "Red + Blue"; prefill copies bands
  from last time.
- Tests: two bands saved and restored; bar + band set keeps both; old sets decode; VoiceOver value
  reads the bands.

## Constraints

Design-system tokens only; strings in `Localizable.xcstrings` with Spanish, edited by hand; no new
`swiftlint:disable`; Swift 6 app target; each package updates `docs/codebase-map.md` via
`python3 scripts/codebase-map.py` when files move; `PrebuiltExercises.json` untouched (variation
plan). Firestore rules and Cloud Functions unaffected (nothing server-side reads gym equipment).

## Verification

- Per package: `swiftlint --strict`; build Development, Mock and `WorkoutSessionActivityExtension`
  with only the known `Messaging.token()` warning; named suites above; full unit bundle with
  `-skip-testing:CompoundUITests` (HealthKit and Live Activity flakes rerun alone).
- G1 proves backwards compatibility with the committed v1 fixture; every later package's new fields
  must keep that test green.
- End to end on the simulator after G6 (Mock scheme): build the 7 kg + 2 × 2 kg stack in a gym,
  start a workout on that machine, check ± steps 7, 9, 11, 14 and the hint "Pin 14 + 2 kg";
  progression suggests +2 kg; a T-bar row steps one plate; a duplicate lat pulldown with the first
  switched off drives the keyboard; two bands saved on a set reappear next session.
- On device by the owner: an existing gym from TestFlight still loads after updating.

## Working rules

- One Opus agent per package, in its own worktree, branch `wp-g<n>-<slug>` off the tip of
  `feature/gym-equipment`, PR into `feature/gym-equipment`. Each agent tests on its own simulator
  with `-parallel-testing-enabled NO`; the lead gates on iPhone 17 Pro Max `383E5B75…`.
- Every new field decodes with a default; `GymProfileDecodingTests` and the v1 fixture stay green.
- `Localizable.xcstrings` by hand, Spanish for every new string, keys sorted; check for duplicate
  top-level keys after any rebase.
- The owner's spreadsheets and real gym data are never committed.

## Status

- 8 Oct 2026: plan approved; branch cut from `development` at `090e3868`.
