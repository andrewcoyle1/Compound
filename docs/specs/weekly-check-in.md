# Weekly check-in — feature spec (v1)

Status: specification for implementation. Written 2026-09-22. Gives meaning to the six
`NutritionStrategySettings` strategy fields (`checkInWeekday`, `fastCheckIn`,
`partialLoggingEnabled`, `weighInEnabled`, `fastingEnabled`, `loggingBreakEnabled`) and builds on
`docs/specs/adaptive-expenditure.md` (the engine and `TargetProposal`).

## 1. Purpose

Once a week, on the user's chosen weekday, walk them through a short flow that cleans up the
week's data and then offers the program update (the target proposal). The Strategy settings
screen already names the modules in order — Introduction, Partial Logging, Weigh-In, Fasting,
Logging Break, Program Update — and its footer says they "can appear during your check in".
This spec makes that literal.

## 2. Data

Two new persisted models, one manager, all following the existing sync-engine pattern
(`CollectionSyncEngine` / `DocumentSyncEngine`, `Mock*`/`Production*` services, registration in
`Dependencies`, `TestManagers` wiring, a `*ManagerKey` in `Keys.swift.example` — remember the
example file must gain the key too, and CLAUDE.md/README's key count of 25 becomes 26).

```
struct NutritionDayAnnotation: DataSyncModelProtocol {     // collection nutrition_day_annotations
    var id: String { dayKey }
    let dayKey: String            // same format as MealLogModel.dayKey
    let authorId: String
    var isPartiallyLogged: Bool   // intake that day is incomplete
    var isFastingDay: Bool        // intentionally ate nothing/little; 0 kcal is real
    var dateModified: Date
}

struct LoggingBreak: DataSyncModelProtocol {                 // document logging_break, one per user
    var id: String = "logging_break"
    let authorId: String
    var startDate: Date
    var endDate: Date?            // nil = open-ended until the user ends it
}

struct CheckInRecord: DataSyncModelProtocol {                // document check_in_record, one per user
    var id: String = "check_in_record"
    let authorId: String
    var lastCompletedWeekStart: Date?   // start of the ISO week of the last completed check-in
    var lastSkippedWeekStart: Date?
}
```

`NutritionStrategyManager` (or extend `NutritionStrategySettingsManager` if that keeps the
file under the length limit) owns the three engines and exposes `dayAnnotations`,
`loggingBreak`, `checkInRecord`, and save/clear functions.

## 3. How the annotations feed the expenditure engine

Extend `DailySample` with `let isExcluded: Bool` (default `false`). `CoreInteractor` sets it when:

- the day's annotation has `isPartiallyLogged == true` → excluded (intake unreliable);
- the day falls inside a `LoggingBreak` → excluded;
- `isFastingDay == true` → **not** excluded; instead, a day with no meal logs is treated as
  logged with 0 kcal (`intakeKcal = 0`). Without the flag such a day is `nil`.

Engine rule: an excluded day's intake is **not observed** by the expenditure filter, and it
counts as unlogged for the 80% calibration gate, but its weigh-in still feeds the trend. Since the
2026-10 filter (`docs/specs/adaptive-expenditure.md` §3.3), any other logged day below half the
current expenditure is treated the same way unless it is marked as a fast: `DailySample` carries
`isFastingDay` so a marked fast's low intake is read as real. Tests: excluded days with wild
intake do not move the estimate; marked fasting days pull it down while the same unmarked zeros
are skipped; a week-long break takes a fully logged window under the 80% gate.

During an open logging break the running estimate is frozen: `CoreInteractor` passes
`today = break.startDate` to the engine so the history stops there, and `TargetProposal` is nil.

## 4. When the check-in is due

`CoreInteractor.checkInState: CheckInState` — `.notDue`, `.due(weekStart: Date)`, `.inBreak`.

Due when all hold: today's weekday == `checkInWeekday` **or** the check-in for this ISO week
has not been completed and today is after `checkInWeekday` in this week (a missed Monday
check-in stays due through Sunday); `checkInRecord.lastCompletedWeekStart` and
`lastSkippedWeekStart` are both before this week's start; no open logging break. Pure function
`CheckInSchedule.state(today:settings:record:break:calendar:)`, unit-tested.

Surface: a card at the top of the nutrition overview ("Weekly check-in ready" with Start and
Skip this week). Skip sets `lastSkippedWeekStart`. The card replaces the plain proposal card
from the expenditure spec when a check-in is due; outside a check-in the proposal card stays as
it is.

## 5. The flow

A single VIPER module `CheckIn` (`Core/Nutrition/CheckIn/`) presented as a sheet, with one
presenter driving an ordered list of steps. Each step is included only when its setting is on
and it has something to ask; the presenter computes `steps` once at start:

| Step | Included when | Content |
|---|---|---|
| Introduction | `fastCheckIn == false` | One screen: this week's logged days, weigh-ins, trend change. Continue. |
| Partial logging | `partialLoggingEnabled` and the week has ≥1 logged day | The week's days as a list; each row shows intake and a toggle "Incomplete". Pre-set from existing annotations. Saves annotations on Continue. |
| Weigh-in | `weighInEnabled` and no weigh-in in the last 3 days | Inline weight entry (reuse the existing log-weight sheet's input, not a new picker). Log or Skip. |
| Fasting | `fastingEnabled` and the week has ≥1 day with no meal logs | Those days listed with a toggle "Fasted". Saves annotations. |
| Logging break | `loggingBreakEnabled` | "Take a break from logging?" Start a break (open-ended; the card and the estimate freeze) or Continue. Shown only if no break is open; if one is open the step offers to end it. |
| Program update | always | The `TargetProposal` if non-nil (Accept applies it via the existing accept path). Otherwise "Your targets are unchanged this week" with the current expenditure (its 80% interval once adaptive, "calibrating" before) and the trend; and, when the target would have come down but the last week's logged intake ran more than 10% over it while the trend is behind the goal, an `AdherenceNote` saying so instead of lowering the target (`docs/specs/adaptive-expenditure.md` §4). Done. |

`fastCheckIn` skips Introduction and, for Partial logging and Fasting, pre-collapses the lists
to only the days that look suspicious (intake < 50 % of the current expenditure for partial —
`ExpenditureEngine.Constants.partialDayFraction`, the same threshold the engine already skips;
no logs for fasting), so a fast check-in with nothing suspicious is two taps: Weigh-in (if
needed) and Program update.

Each step's header carries an ⓘ: the weight trend (Introduction), the check-in rules (Partial
logging, Fasting), the target controller (Program update with a proposal or an adherence note) and
adaptive expenditure (Program update without one). These rules rest on under-reporting being
common and largest on partly logged days (Lichtman 1992) and on the filter treating missing intake
as missing rather than imputed (Guo 2017); the 50% threshold and the three-day weigh-in window are
design choices.

Completing the last step sets `lastCompletedWeekStart`. Dismissing the sheet part-way keeps
annotations already saved and leaves the check-in due.

Events: `CheckInPresenter.Event` cases for start, each step shown, each step's outcome, complete,
skip, dismiss, with the step name as a parameter.

## 6. Tests

- `CheckInScheduleTests`: due on the weekday; still due later in the week if not completed;
  not due after completion or skip; not due next week's earlier days; due again the following
  check-in day; `.inBreak` during an open break; weekday 7 (Saturday) and 1 (Sunday) around the
  ISO week boundary.
- `ExpenditureEngineTests` additions for §3.
- `NutritionStrategyManagerTests` (via `TestManagers`, `eventually`): annotation save/replace by
  dayKey, break start/end, record update.
- `CheckInPresenterTests`: step list for every combination of the four toggles with a week of
  fixture data; `fastCheckIn` drops Introduction; weigh-in step absent when a weigh-in is 2 days
  old; program update shows the proposal when present and the unchanged copy when not;
  completing writes `lastCompletedWeekStart`; dismissing mid-flow does not.

## 7. Out of scope

Push notifications on the check-in day, coaching text generated by the AI backend, and any
change to the Strategy settings screen beyond making its existing controls true.
