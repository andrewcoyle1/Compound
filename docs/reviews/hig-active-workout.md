# Active workout, Live Activity and widgets: HIG review (2026-09-28)

Reviewed against the live HIG with the `apple-hig` skill, `--platform ios`. Pages read:
`designing-for-ios`, `workouts`, `live-activities`, `widgets`, `playing-haptics`, `playing-audio`,
`notifications`, `managing-notifications`, `entering-data`, `virtual-keyboards`, `steppers`,
`buttons`, `feedback`, `undo-and-redo`, `always-on`, `accessibility`, plus `alerts`,
`action-sheets`, `modality`, `writing` and `materials`, which the code turned out to need.

**Scope.** Code read: `Core/Training/Subviews/WorkoutTracker/**` (tracker, exercise and set
trackers, set row, set keyboard, warm-up sets, notes, swap picker, equipment sheet),
`Core/Training/Components/TrainingAccessory/`, `WorkoutSessionActivity/**`, `Shared/**`,
`Managers/LiveActivities/**`, `Managers/Training/WorkoutRestTimerIntents.swift`,
`Managers/Training/WorkoutFinishing.swift`, the rest timer in `Managers/HKWorkout/`,
`Managers/Push/PushManager.swift`, the notification delegate in `Root/AppDelegate.swift`, and the
rest-timer settings screen. The Swiftful sound and haptics packages were read in DerivedData to
confirm what they do with the audio session.

**Not reviewed.** `WorkoutSessionDetail`, the exercise picker reached from "Add exercise",
Set Targets, Exercise Settings, Workout Settings beyond the rest-timer section, and the
`CustomModalView` that hosts the rest picker.

**Not repeated.** Everything in `docs/reviews/live-activity-review.md` (F1–F14, D1–D12) and
`docs/specs/live-activity.md`. Those are about correctness; this is about the guidelines. Where a
finding touches a choice the Live Activity spec made on purpose, it says so and asks for a decision.

**Not checked.** This is a code review. Nothing was built or run, so Dark Mode, the largest text
sizes, VoiceOver, iPad, StandBy, the Always-On display and Mac Catalyst are all unverified. Sizes
given for controls are read off the modifiers, not measured.

Paths are relative to `DialedIn/` unless they start with `WorkoutSessionActivity/` or `Shared/`.
Line numbers are from the working tree at review time. `WorkoutTrackerPresenter.swift`,
`WorkoutTrackerInteractor.swift` and `PushManager.swift` had uncommitted edits by someone else
while this was written, so their numbers may have moved by a few lines.

## Decisions built (2026-09-29, branch hig/workout2)

| Decision | Status | What changed |
|---|---|---|
| W1 | built in part | `UIBackgroundModes` = `processing` in `Info.plist.example`, as Apple's iOS 26 workout sample declares (no `INFOPLIST_KEY_` setting exists for it); the owner's own `Info.plist` needs the same. The rest-over choice is `RestOverAlert.channel`, tested; the rest timer's leeway is 100 ms. The 2 s notification stays for everyone. Unverified on a device. |
| W3 | built in part | `paused_seconds` (optional) stamped at finish from the tracker and the Live Activity, a running pause included; `activeDuration` read by the detail and its editor, feed rows, share card, Live Activity summary and Strava. The rest-over distance follows the exercise's unit via an optional `distanceUnit` on the activity state; `Dependencies.swift` must pass it, and the server share page (`functions/lib.js`) still shows wall time. |
| 11d | built | "Upload Workouts to Strava?" (Connect Strava / Not Now) over the session detail once the first finished workout has saved and Strava is not connected; answered once per person. `StravaOffer.shouldOffer` is tested. |

## Decisions built (2026-09-29, branch hig/workout)

| Decision | Status | What changed |
|---|---|---|
| 4 | built | `HKWorkoutManager` owns the rest-over alert: `startRest` schedules (or moves) it, `cancelRest` (skip, finish, discard) withdraws it, `endRest` alerts through the Live Activity with an `AlertConfiguration`. The notification is the alert with Live Activities off, and otherwise a backstop 2 s after the end for a suspended app, withdrawn when the app gets there first. `willPresent` returns `[]` for it. |
| 4a | built | A system sound (1007) stands in for the missing file, with a TODO; the file, once added, plays under `.ambient`. Both follow the silent switch and mix with music. |
| 4b | built | "Next: Bench Press, 60 kg × 8" through `Format.*` in the exercise's weight unit; "Next: Bench Press" with no figures; title only ("Rest Complete") when nothing is left. |
| 5a | built | Logged sets move when tracking mode and per-side match; open sets are replaced, as many as were open. Otherwise "Discard Logged Sets?" with "Swap and Discard Sets" / Cancel. The picker hands over its choice after its sheet closes. |
| 5b | built | *Amended 2026-10-06 (hig-decisions T2): visible toolbar items at regular width.* Pause Workout / Resume Workout in the menu, through `togglePause()`. The pause lives on `HKWorkoutManager` (works without HealthKit); the clock leaves paused time out; the Live Activity shows its paused phase, and intent pushes follow it. |
| 5c | built | Finish opens the existing session detail once the cover is down; success haptic on save and on a retried save; "No Sets Logged" with Discard Workout / Save Anyway / Cancel. |
| 5d | built | *Reversed 2026-10-06 (hig-decisions T1): Done only closes; WP-F.* Done logs a ready set; no alert. The event name is kept. |
| 12c | built | Rows and container: fixed height up to `.large`, minimum height above it. Ceiling AX1 on the banner and the expanded island (by the HIG's leading, AX2 would need about 163 pt of the 160). Not captured: the screenshot script cannot show a Live Activity. |
| 12d | built | "Show on Lock Screen" under Display, default on (optional field, nil reads on), read in `CoreInteractor.ensureLiveActivity`. |
| 13b | built | At accessibility sizes each set row stacks into two lines (set, Prev/Auto, Done; then the inputs across the width) and the headers follow; the xxxLarge cap is gone. Normal sizes unchanged. |

## Resolution (2026-09-28, branch hig/workout)

| # | Status | What changed |
|---|---|---|
| 1 | skipped: decision | Swap still replaces logged sets. |
| 2 | skipped: decision | Notification scheduling untouched; the permission request in `PushManager` stays. The in-app +15s moves the rest through `startRest` and, like the Lock Screen's, leaves the notification where it was. |
| 3 | fixed | Complete and note buttons pad their label with `.tapTarget()`; set number, add set, the exercise capsules, Prev/Auto and the unit menus use `.controlSize(.large)` glass. Set and Done columns 44 pt, Prev 78 pt. Unmeasured. |
| 4 | fixed | `widgetURL` on the banner and the island. `showWorkoutTrackerView()` (every entry point, including the tab bar's deep link) presents under a fixed id and returns when that screen is already up. |
| 5 | fixed | +15s and Skip on the rest pill, 44 pt targets; the elapsed-time fallback is gone. |
| 6 | skipped: decision | |
| 7 | skipped: decision | |
| 8 | fixed | `chevron.down` "Minimize workout" in `.cancellationAction`; the menu item removed. |
| 9 | skipped: decision | Only text weights changed (finding 14). |
| 10 | skipped: decision | The Done prompt and superset alert are unchanged. The unit-change alerts became confirmation dialogs, as `hig-handoffs.md` asked. |
| 11 | skipped: decision | |
| 12 | fixed | Keys and `String(localized:)` throughout; Spanish added to the widget catalog, "%lld exercises" plural, "days streak" reads "day streak" in English. |
| 13 | fixed | "Discard Workout" / "Discard Workout?" / "The sets you logged will not be saved." |
| 14 | fixed | Compact trailing `.caption.weight(.semibold)`, primary, monospaced; banner body medium. |
| 15 | fixed | `.after(.now + 30 * 60)`. |
| 16 | skipped: decision | |
| 17 | fixed | `Image(decorative:)`; island image and ring labelled; progress line has a label and value. |
| 18 | fixed | The keyboard sits in a `UIInputView` adopting `UIInputViewAudioFeedback`; every key plays the input click. |
| 19 | fixed | Verb-first descriptions, Streak and Weekly Goal link to `compound://tab/training`, `widgetAccentable` on the flame, Today label, play icon and ring. The ring track's opacity is unchanged. |
| Smaller | fixed | Rest-over haptic is `.warning`; keypad shows the region's separator and parses with `Double.typed`; summary volume in the user's unit and locale formatting; 14 pt margin; `keylineTint`; "Fills this set" hints; the validation alerts reworded. |

## Findings

### 1. Swapping an exercise throws away the sets already logged for it, without asking
Severity: hurts usability (data loss)
Where: `Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerPresenter.swift:67-85`
(the write is `:76`), reached from `SetTrackerView.swift:87-91`
Guideline: "Warn people when they initiate a task that can cause data loss that's unexpected and
irreversible." — https://developer.apple.com/design/human-interface-guidelines/feedback
What happens: choosing a replacement in the Swap sheet assigns `exercise.sets` three fresh default
sets. If two sets of the original were already logged, they are gone, the session is saved
immediately through `workoutSession.didSet`, and nothing can bring them back. Deleting the
exercise, which loses the same data, does confirm (`:48-56`).
Fix: when `exercise.sets.contains { $0.completedAt != nil }`, either keep the logged sets and
replace only the open ones, or confirm first through `router.showConfirmationDialog` with a
destructive "Swap and Discard Sets" and Cancel. Keeping them is the smaller surprise.
Size: S
Decision needed: yes — keep the logged sets under the new exercise, or confirm and discard.

### 2. The rest-over notification is scheduled once and never moved or removed
Severity: hurts usability
Where: `Core/Training/Subviews/WorkoutTracker/WorkoutTrackerPresenter+Rest.swift:110-131`
(schedule); `Managers/LiveActivities/LiveActivityIntentHandler+App.swift:121-140` (+15s and Skip
leave it alone) and `:190-217` (a rest started from the Live Activity schedules none);
`Managers/HKWorkout/HKWorkoutManager.swift:137-143`, `:180-193` (finish and discard leave it
alone); `Root/AppDelegate.swift:139` (shown as banner with sound while the app is in front);
`WorkoutTrackerPresenter+Rest.swift:89-97` (the app's own sound and haptic at the same moment)
Guideline: "avoid alerting people too often or with updates that aren't crucial, and don't use
push notifications alongside Live Activities for the same updates." —
https://developer.apple.com/design/human-interface-guidelines/live-activities
"Handle notifications gracefully when your app is in the foreground… present the information in a
way that's discoverable but not distracting or invasive" and "Avoid sending a notification that
tells people to perform specific tasks within your app." —
https://developer.apple.com/design/human-interface-guidelines/notifications
Caveat: the Live Activities sentence says push notifications and this one is local. Applying it
is a reading; the foreground and the wording points are direct.
What happens: no code removes or reschedules the `workout-rest-timer` request. Skip on the Lock
Screen ends the rest, and "Rest Complete" still arrives at the original time, mid-set. "+15s"
makes it arrive fifteen seconds early. Finishing or discarding during a rest delivers it after
the workout is over. A set completed from the Live Activity starts a rest with no notification at
all, so the same event behaves differently depending on where the set was logged. With the
tracker on screen the user gets the app's sound and haptic plus a banner with its own sound. The
body, "Time to get back to your workout!", is an instruction.
Fix: give the rest one owner. Schedule in `HKWorkoutManager.startRest` and remove the pending
request in `cancelRestTimer()`, so every start, adjust, skip, end and discard is covered from one
place. In `willPresent`, return `[]` for that identifier. Change the body to a statement, for
example "Next: Bench Press, 60 kg × 8". Better still, make the Live Activity the channel: pass an
`AlertConfiguration` on the update in `endRest()` and keep the notification only for users with
Live Activities turned off.
Size: M
Decision needed: yes — Live Activity alert or notification as the one rest-over channel.
Note: an uncommitted edit in `PushManager.schedulePushNotification` now asks for notification
permission here, so the system alert appears when the first rest starts. The timing fits the
privacy guidance; whatever replaces the scheduling must keep that request.

### 3. The control that logs a set is 32 pt wide
Severity: hurts usability
Where: `…/SetTracker/SetTrackerRow/SetTrackerRowView.swift:238-253` (complete button, 32 wide,
35 pt minimum height, `.plain`); `:72-91` (set number menu, 34 wide); `SetTrackerView.swift:195-211`
(add set, 34 wide, `.caption` symbol); `:63-130` (Equipment, Warmup, Targets, Swap, Superset and
More, `.caption` capsules); `:179-193` (Prev/Auto, `.caption2`); `:214-259` (unit menus,
`.caption2`); `ExerciseTracker/ExerciseTrackerView.swift:127-139` (note button, bare symbol,
`.borderless`)
Guideline: "Provide workout controls that are easy to find and tap." —
https://developer.apple.com/design/human-interface-guidelines/workouts
"As a general rule, a button needs a hit region of at least 44x44 pt" —
https://developer.apple.com/design/human-interface-guidelines/buttons
What happens: the most used control in the app has a hit region of about 32×35 pt, and it sits
8 pt from the reps field. It is tapped between sets, often one handed. None of the other seven
sites pads its hit area either. Nothing was measured; the numbers are the frames in the code.
Fix: the project already has the pattern in `.chipTapTarget()` (`Components/DesignSystem/Chip.swift:64`).
For the complete button:
```swift
Image(systemName: state.systemImage)
    .font(.title3)
    .foregroundStyle(state.tint)
    .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
    .contentShape(.rect)
```
and widen its column and the "Done" header to match (`SetTrackerView.swift:142-143`). The Prev
column is 90 pt and can give up the 12 pt. Apply the same minimum to the other sites.
Size: M
Decision needed: no

### 4. Tapping the Live Activity does not open the workout
Severity: hurts usability
Where: `WorkoutSessionActivity/WorkoutSessionActivity.swift:24-40`,
`WorkoutSessionActivity/LiveActivityView.swift:28-43` (no `widgetURL` on the banner or any island
region); compare `WorkoutSessionActivity/HomeWidgets.swift:39`
Guideline: "Make sure tapping the Live Activity opens your app at the right location. Take people
directly to related details and actions — don't make them navigate to find relevant information."
and "Ensure both leading and trailing elements link to the same screen." —
https://developer.apple.com/design/human-interface-guidelines/live-activities
What happens: the Today's Workout widget links to `compound://workout`, which the tab bar turns
into the tracker. The Live Activity, which is the workout, has no link, so a tap opens the app
wherever it was left. If the tracker was minimized, that is a tab, and the `.paused` row tells the
user to "Resume in the app" without taking them there.
Fix: add `.widgetURL(WidgetSnapshotStore.workoutURL)` to `LiveActivityView` and to the
`DynamicIsland` closure. `TabBarPresenter`'s `.workout` case (`Core/TabBar/TabBarPresenter.swift:79-89`)
calls `showWorkoutTrackerView()` unconditionally, so guard it against presenting a second tracker
over one that is already open.
Size: S
Decision needed: no

### 5. The rest timer in the app can only be watched
Severity: hurts usability
Where: `Core/Training/Subviews/WorkoutTracker/WorkoutTrackerView.swift:37-41`, `:170-194`;
`WorkoutTrackerPresenter+Rest.swift:70-76` (`cancelRestTimer()`, which no view calls)
Guideline: "Provide workout controls that are easy to find and tap." —
https://developer.apple.com/design/human-interface-guidelines/workouts
"Consider pairing a stepper with a text field when large value changes are likely." describes the
same need for small adjustments — https://developer.apple.com/design/human-interface-guidelines/steppers
What happens: the Lock Screen offers +15s and Skip. The glass pill in the tracker shows the same
countdown with no controls. To skip a rest inside the app the user has to lock the phone or
complete the next set. The pill is also one combined accessibility element, so VoiceOver has
nothing to act on.
Also still true from `docs/ui-audit.md`: when the rest has passed but the view has not yet been
invalidated, the pill shows the workout's elapsed time under the caption "Rest Timer" (`:181-184`).
Fix: add Skip and +15s to the pill, calling `interactor.cancelRest()` and a new
`interactor.adjustRest(by:)` that goes through the same `HKWorkoutManager.startRest` the intent
handler uses. Give each a 44 pt target. Delete the `else` branch; when there is no running rest
the pill should not be drawn.
Size: M
Decision needed: no

### 6. There is no pause, and the Live Activity has a paused state nothing can reach
Severity: hurts usability
Where: `WorkoutTrackerView.swift:199-202` (the comment records the removal);
`WorkoutTrackerPresenter.swift:47` (`isActive` is never assigned again);
`Managers/HKWorkout/HKWorkoutManager.swift:116-135` (`pause`, `resume`, `togglePause` have no
callers); `WorkoutSessionActivity/LiveActivityPhaseViews.swift:62-64`, `:253-266`
Guideline: "In addition to making it easy for people to pause, resume, and stop a workout, be sure
to provide clear feedback that indicates when a session starts or stops." —
https://developer.apple.com/design/human-interface-guidelines/workouts
What happens: the elapsed clock and the HealthKit session run from start to finish. A user who
stops to take a call has a longer workout and more active time recorded than they did. The
banner's "Paused · Resume in the app" row exists for a state the app cannot enter or leave.
Fix: either add Pause and Resume to the tracker menu, wired to `togglePause()` and to `isActive`
so the banner follows, or decide strength sessions do not pause and delete the `.paused` phase,
its row and the three `HKWorkoutManager` methods.
Size: M
Decision needed: yes — does a strength workout pause?

### 7. Finishing a workout gives no summary and no confirmation, and an empty one is saved
Severity: hurts usability
Where: `WorkoutTrackerPresenter+Finish.swift:61-74`, `:94-96` (`.saved` does nothing);
`WorkoutTrackerPresenter+Notes.swift:26-48` (no check on what was logged);
`WorkoutTrackerView.swift:208-212` (Finish is always enabled)
Guideline: "Provide a summary at the end of a session. A summary screen confirms that a workout is
finished and displays the recorded information." and "Discard extremely brief workout sessions. If
a session ends a few seconds after it starts, either discard the data automatically or ask people
if they want to record the data as a workout." —
https://developer.apple.com/design/human-interface-guidelines/workouts
What happens: Finish dismisses the tracker and returns to whatever was underneath. The only
summary is the Live Activity's, on the Lock Screen, which the user is not looking at. A successful
save shows no toast and plays no haptic, although the contract asks for `.success` after a finish
and WP-09 describes the flow as having a "confirmation, summary and haptic". A workout finished
with no set logged is saved, counts toward the streak and is uploaded to Strava.
Fix: after the notes sheet, route to the existing session detail for the finished session, or to
a short summary sheet with duration, sets and volume. Call `interactor.playHaptic(option: .success)`
on `.saved`. When no set has `completedAt`, replace Finish with a confirmation dialog: "No sets
logged" with "Discard Workout" (destructive), "Save Anyway" and Cancel.
Size: M
Decision needed: yes — summary screen, or session detail reused.

### 8. The tracker is a full-screen modal with no visible way out
Severity: hurts usability
Where: `WorkoutTrackerView.swift:196-236` (one toolbar item, a More menu); `:258-264`
(`.fullScreenCover`)
Guideline: "Always give people an obvious way to dismiss a modal view… in iOS, iPadOS, and watchOS
apps, people typically expect to find a button in the top toolbar or swipe down" —
https://developer.apple.com/design/human-interface-guidelines/modality
What happens: a full-screen cover cannot be swiped down, and the leading side of the bar is
empty. Leaving the tracker to look something up means opening the More menu and finding "Minimize
Tracker". Every sheet the tracker presents follows the contract's close pattern; the tracker
itself is the exception.
Fix:
```swift
ToolbarItem(placement: .topBarLeading) {
    Button { presenter.minimizeSession() } label: { Image(systemName: "chevron.down") }
        .accessibilityLabel("Minimize workout")
}
```
and drop the menu item. A chevron rather than `role: .close`, because the workout keeps running.
Size: S
Decision needed: no

### 9. The Live Activity's rows are 38 pt high whatever the text size, and so are its buttons
Severity: hurts usability — **by arithmetic, not run**
Where: `WorkoutSessionActivity/LiveActivityPhaseViews.swift:21-28` (constants), `:108`, `:122`,
`:138`, `:183`, `:234`, `:250`, `:265`, `:281` (every row is `.frame(height: 38)`); `:144-156`
(−/+ reps, `.footnote` symbol, 2 pt padding), `:212-232` (+15s and Skip, `.footnote`);
`WorkoutSessionActivity/LiveActivityView.swift:37`
Guideline: "In iOS, iPadOS, and visionOS, widgets support Dynamic Type sizes from Large to AX5" —
https://developer.apple.com/design/human-interface-guidelines/widgets
"Dynamically change the height of your Live Activity on the Lock Screen or in the expanded
presentation." and "If you offer interactivity, prefer limiting it to a single element to help
people avoid accidentally tapping the wrong control." —
https://developer.apple.com/design/human-interface-guidelines/live-activities
What happens: a `.headline` name over a `.subheadline` position is about 42 pt of text in a 38 pt
row at the default size. It fits only because the frame does not clip. At accessibility sizes the
two rows grow into each other inside an 82 pt container. Every button is capped by the same row,
so none reaches 44 pt, and the resting phase puts four of them in two rows: −, + (8 pt apart),
+15s and Skip.
This is partly a choice: spec §3 fixes the height so the banner does not jump, and gives the
resting phase its correction window on purpose.
Fix: replace `.frame(height:)` with `.frame(minHeight:)` on the rows and on the container, so the
banner keeps its height at default sizes and grows up to the system's 160 pt when text needs it.
Add `.dynamicTypeSize(...DynamicTypeSize.accessibility2)` as the ceiling that still fits two rows.
Make −/+ one 44 pt tall control with `.controlSize(.large)`, and consider dropping +15s from the
banner once the app has it (finding 5).
Size: M
Decision needed: yes — whether the banner may grow, and whether resting keeps four controls.

### 10. Alerts are used for choices and for a routine step
Severity: hurts usability
Where: `…/SetTrackerRow/SetTrackerRowPresenter.swift:292-304` ("Complete Set?" after the
keyboard's Done, on every ready set); `…/SetTracker/SetTrackerPresenter.swift:109-128` ("Add to
Group", one button per exercise in the workout); `:239-260`, `:263-284` (unit change, three
choices)
Guideline: "Use alerts sparingly… they interrupt the current task" and "Use an action sheet — not
an alert — to offer choices related to an intentional action." —
https://developer.apple.com/design/human-interface-guidelines/alerts
"When possible, avoid displaying an alert that scrolls." — same page
What happens: entering reps and pressing Done raises an alert for every set of the workout. The
superset picker is an alert that grows a button per exercise, so a ten-exercise workout gives an
alert that scrolls. The unit change offers "Display Only" and "Convert Values" in an alert.
Fix: `router.showConfirmationDialog` already exists (`Root/RIBs/GlobalRouter.swift:74`); use it for
the unit change. Present the superset partners as a `.compact` sheet of `SelectableRow`s. For
Done, remove the prompt: either Done only closes the keyboard and the row's circle logs the set,
or Done logs a ready set directly. The un-complete tap already undoes a mistake.
Size: M
Decision needed: yes — what Done does on a ready set.

### 11. "Play Sound" plays nothing in the app, and will stop the user's music when it does
Severity: hurts usability
Where: `Managers/SoundEffects/SoundEffectFile.swift:14-17`, `:31-34` (`RestComplete.wav` is not in
the repository; no audio file is); `Core/Profile/Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings/RestTimerSettingsView.swift:77-82`;
`WorkoutTrackerPresenter+Rest.swift:91-93`, `:103-105`. No `AVAudioSession` call exists in the app
or in `SwiftfulSoundEffects`, which plays through `AVAudioPlayer`.
Guideline: "Choose an audio category that fits the way your app or game uses sound… don't make
people stop listening to music from another app if you don't need to." and, for iOS, "Use the
system's sound services to play short sounds and vibrations." —
https://developer.apple.com/design/human-interface-guidelines/playing-audio
What happens: the setting says "Play sound when rest time is over". With the tracker open it does
nothing, because the file is missing; the only sound comes from the notification (finding 2). When
the file is added, the player will run under the default solo-ambient session, which "silences
other audio" per the page's table. In a gym that is the user's music.
Fix: add the sound, and before the first play set the session to `.ambient` (mixes, follows the
silent switch) or `.playback` with `.mixWithOthers` and `.duckOthers` (mixes, ignores the silent
switch). Or play it through `AudioServicesPlaySystemSound`, which needs no session.
Size: S
Decision needed: yes — whether the rest sound should play with the phone on silent.

### 12. Half the Live Activity and the Today widget cannot be translated
Severity: hurts usability (Spanish)
Where: `WorkoutSessionActivity/LiveActivityPhaseViews.swift:56` ("Rest over"), `:59` ("All sets
complete"), `:64` ("Paused"), `:131` ("set"), `:271`, `:274`, `:277` ("Duration", "Sets",
"Volume"); `Shared/LiveActivityPhase.swift:113` ("Set 2 of 4", "Warmup 1 of 2");
`WorkoutSessionActivity/HomeWidgets.swift:62` ("No workout planned"), `:81-84` ("Open to pick one",
"Rest day", "Done", and a hand-written plural), `:129` ("days streak")
Guideline: "Choose simple, plain language and write with accessibility and localization in mind" —
https://developer.apple.com/design/human-interface-guidelines/writing
What happens: these strings are passed as `String` values, so `Text` never looks them up, and none
of them is in `WorkoutSessionActivity/Localizable.xcstrings`. A Spanish user sees "Completar" on
the button beside "Rest over" and "Set 2 of 4". "12 days streak" is also wrong in English.
Fix: take `LocalizedStringKey` or `LocalizedStringResource` in `doneRow`, `pausedRow`,
`targetActionRow(prefix:)` and `summaryMetric(title:)`; build `SetPosition.label` and the widget's
`detail` with `String(localized:)`; use the catalog's plural variations for exercises and for
"%lld day streak", which the catalog already has for the accessory widget.
Size: S
Decision needed: no

### 13. Discarding a workout is called three different things
Severity: polish
Where: `WorkoutTrackerView.swift:226-230` ("Delete Workout");
`WorkoutTrackerPresenter.swift:276-290` ("End Workout?", "Are you sure you want to discard this
workout?", "Discard")
Guideline: "Write a title that clearly and succinctly describes the situation." and "Prefer verbs
and verb phrases that relate directly to the alert text" —
https://developer.apple.com/design/human-interface-guidelines/alerts
"Build language patterns. Consistency builds familiarity" —
https://developer.apple.com/design/human-interface-guidelines/writing
What happens: the menu says Delete, the title says End, the message and button say Discard. "End
Workout?" reads as finishing, which is the opposite. The message is a bare string literal passed
as `String?`, so it is not in the catalog and is shown in English to everyone.
Fix: "Discard Workout" in the menu; title "Discard Workout?"; message
`String(localized: "The sets you logged will not be saved.")`; buttons "Discard" and Cancel.
Size: S
Decision needed: no

### 14. Live Activity text is small, regular weight and secondary
Severity: polish
Where: `WorkoutSessionActivity/WorkoutSessionActivity.swift:81-84`, `:87-89`, `:96-103` (compact
trailing: `.footnote`, `.secondary`); `WorkoutSessionActivity/LiveActivityPhaseViews.swift:77`
(body of the banner is `.subheadline` regular), `:194-196` (`.caption`), `:286-288` (`.caption2`)
Guideline: "Ensure text is easy to read. Use large, heavier-weight text — a medium weight or
higher. Use small text sparingly and make sure key information is legible at a glance." —
https://developer.apple.com/design/human-interface-guidelines/live-activities
"Make sure text is legible for when people are in motion… use large font sizes, high-contrast
colors" — https://developer.apple.com/design/human-interface-guidelines/workouts
What happens: in the compact island the one piece of information, the next set or the countdown,
is 13 pt regular in grey on black. In the banner only the exercise name and the target are
heavier than regular.
Fix: compact trailing to `.caption.weight(.semibold)` in `.primary`, with `.monospacedDigit()` on
the target as well as the timer. Give the banner's detail text `.weight(.medium)`.
Size: S
Decision needed: no

### 15. A finished workout stays on the Lock Screen for up to four hours
Severity: polish
Where: `Managers/LiveActivities/LiveActivityManager.swift:125`, `:132`
Guideline: "Consider choosing a custom dismissal time that's proportional to the duration of your
Live Activity. In most cases, 15 to 30 minutes is adequate." —
https://developer.apple.com/design/human-interface-guidelines/live-activities
Fix: `isCompleted ? .after(.now + 30 * 60) : .immediate`.
Size: S
Decision needed: no

### 16. The Live Activity cannot be turned off from inside the app
Severity: polish
Where: `WorkoutTrackerPresenter.swift:126-134` (started for every workout); no setting in
`Managers/Training/WorkoutSettings/Models/WorkoutSettings.swift` or the Workout Settings screens
Guideline: "Start Live Activities at appropriate times, and make it easy for people to turn them
off in your app… When people can't easily control the appearance of Live Activities from your
app, they may choose to turn off Live Activities in Settings altogether." —
https://developer.apple.com/design/human-interface-guidelines/live-activities
Fix: a "Show on Lock Screen" `ListRowToggle` in Workout Settings, under Display, read in
`ensureLiveActivity`. Default on.
Size: S
Decision needed: yes — worth a setting, or leave it to the system toggle.

### 17. VoiceOver is given the asset name and no workout progress
Severity: polish — **unverified, not run**
Where: `WorkoutSessionActivity/LiveActivityPhaseViews.swift:306-312` (`Image(imageName)`);
`WorkoutSessionActivity/LiveActivityView.swift:46-57` (progress line);
`WorkoutSessionActivity/WorkoutSessionActivity.swift:67-69`, `:106-115` (compact leading and
minimal are the image or a bare ring)
Guideline: "Describe your app's interface and content for VoiceOver." and "Convey information with
more than color alone." — https://developer.apple.com/design/human-interface-guidelines/accessibility
What happens: `Image(_:)` takes its label from the asset name, so the banner would read
"BarbellBenchPress" before "Bench Press". The whole-workout progress is two rectangles with no
label or value. In the minimal presentation the image is the only content.
Fix: `Image(decorative: imageName)` in the banner; on the island's image and ring add
`.accessibilityLabel(state.currentExerciseName ?? "Workout")`; on the progress line
`.accessibilityElement()`, `.accessibilityLabel("Workout progress")` and
`.accessibilityValue("\(completedSetsCount) of \(totalSetsCount) sets")`.
Size: S
Decision needed: no

### 18. The set keyboard is silent
Severity: polish
Where: `…/SetTrackerRow/SetKeyboard/SetKeyboardView.swift:224-249`;
`SetKeyboardTextField.swift:27-35`
Guideline: "Play the standard keyboard sound while people type. The keyboard sound provides
familiar feedback when people tap a key on the system keyboard, so they're likely to expect the
same sound when they tap keys in your custom input view." —
https://developer.apple.com/design/human-interface-guidelines/virtual-keyboards
Fix: host the keyboard in a `UIInputView` subclass that adopts `UIInputViewAudioFeedback` with
`enableInputClicksWhenVisible` returning true, and call `UIDevice.current.playInputClick()` from
`type(_:)` and `backspace()`. It follows the user's keyboard-clicks setting.
Size: S
Decision needed: no

### 19. Widgets: descriptions, links and tinted appearance
Severity: polish
Where: `WorkoutSessionActivity/HomeWidgets.swift:41-42`, `:96-97`, `:146-147` (descriptions);
`:92-95`, `:142-145` (Streak and Weekly Goal have no `widgetURL`); whole file (no
`widgetAccentable`, no `widgetRenderingMode`); `:159-160` (ring track is `.tint.opacity(0.2)`)
Guideline: "Begin a description with an action verb… Avoid including unnecessary phrases" ;
"Ensure that a widget interaction opens your app at the right location." ; "Group widget
components into an accented and a primary group." ; "use opaque grayscale values, rather than
opacities of white, to achieve the best vibrant material effect." —
https://developer.apple.com/design/human-interface-guidelines/widgets
What happens: the three descriptions are noun phrases ("Your current training streak."). Streak
and Weekly Goal open the app wherever it was. Under a tinted or clear Home Screen everything falls
into one group, so the flame, the ring and the numbers are the same white.
Fix: "See today's session from your program.", "Track your training streak.", "Check this week's
sessions against your goal." Link Streak and Weekly Goal to `compound://tab/training`. Mark the
flame, the "Today" label and the ring's filled arc `.widgetAccentable()`.
Size: S
Decision needed: no

## Smaller items

- The rest running out and a set being logged play the same `.success` haptic
  (`WorkoutTrackerPresenter+Rest.swift:95`, `SetTrackerRowPresenter.swift:57`). "Use haptics
  consistently… so people learn to associate certain haptic patterns with certain experiences"
  (playing-haptics). My judgment: `.warning` or an impact for rest-over would tell them apart.
- The keypad's decimal key and every field show "." in all locales
  (`SetKeyboard/WeightStepper.swift:216-219` uses `String(Double)`), while `Format.weight` beside
  them is locale aware. Entering-data suggests a number formatter; the contract requires one.
- The Live Activity's end summary is always in kilograms and built with `String(format:)`
  (`WorkoutSessionActivity/LiveActivityPhaseViews.swift:369-387`); `Shared/LiveActivityPhase.swift:164-182`
  formats distance the same way. The tracker shows volume in the user's unit.
- The banner's horizontal padding is 16 (`WorkoutSessionActivity/LiveActivityView.swift:38`). "The
  standard layout margin for Live Activities on the Lock Screen is 14 points" (live-activities).
- No `keylineTint` is set on the island. "Tint your Live Activity's key line color so that it
  matches your content" (live-activities).
- The Prev and Auto values are buttons that fill the row (`SetTrackerRowView.swift:191-196`,
  `:264-269`) with no hint, so VoiceOver reads a number and "button". Add
  `.accessibilityHint("Fills this set")`.
- "Invalid Set Data" with "Reps must be a positive number" (`SetTrackerRowPresenter.swift:160-195`)
  is the wording the writing page warns about ("Avoid robotic error messages"). The button is
  disabled before most of these can appear, so they are close to dead code.

## Contract conflicts

- **Glass buttons inside list rows.** `CONTRACT.md` makes `.glass` the secondary button. The set
  tracker uses it in the content layer for the set number, add set, the six exercise actions,
  Prev/Auto and the unit menus (`SetTrackerRowView.swift:85`, `SetTrackerView.swift:125`, `:189`,
  `:205`, `:234`, `:257`). "Don't use Liquid Glass in the content layer… use standard materials
  for elements in the content layer" and "Use Liquid Glass effects sparingly." —
  https://developer.apple.com/design/human-interface-guidelines/materials
- **Finish Workout lives in the More menu** (README decision 3) until every set is logged.
  "Provide workout controls that are easy to find and tap… making it easy for people to pause,
  resume, and stop a workout" — https://developer.apple.com/design/human-interface-guidelines/workouts
  The quick-finish button softens this; it does not help someone stopping early.
- **Dynamic Type is capped** at `xxxLarge` on set rows and headers and `xxLarge` on the keyboard
  (`SetTrackerRowView.swift:41`, `:69`; `SetTrackerView.swift:149`; `SetKeyboardView.swift:36`).
  WP-09 says to keep the caps. "Ideally, give people the option to enlarge text by at least 200
  percent" — https://developer.apple.com/design/human-interface-guidelines/accessibility
  `xxxLarge` is about 135 percent of the default body size. A stacked row layout at accessibility
  sizes would lift the cap; that is a redesign, not a fix.

## Done well — keep

- The set row's Done column has three states, each with its own symbol and spoken value, so none
  is told apart by color alone (`SetTrackerRowPresenter.swift:222-256`).
- The set keyboard is a real input view: hardware keys type into it, Return moves to the next
  field, every key is at least 46 pt and scales, chips use `.chipTapTarget()`, the RPE chips carry
  `.isSelected`, and the ± stepper names its step and sits beside the field it changes.
- Quick finish announces itself to VoiceOver and falls back to opacity under Reduce Motion
  (`WorkoutTrackerView.swift:50-53`, `WorkoutTrackerPresenter+Finish.swift:54-57`).
- Sound and vibration for rest-over are separate settings, and the notification's sound follows
  the same one.
- A failed save says where the workout is and what to do: "It's still on this device — resume it
  from Training."
- The Live Activity shows one prominent button per phase, uses the system timer views so it does
  not spend updates on a countdown, and carries nothing sensitive.
- An App Shortcut starts a workout (`Managers/AppIntents/DialedInAppIntents.swift:87`, `:155`), and
  the Today widget deep-links to the tracker.
- The accessory and ring widgets have combined accessibility labels, and the widgets use
  `containerBackground`, so StandBy can remove it.
- The tracker's sheets all use `role: .close` and `role: .confirm`, and deleting an exercise
  confirms with a destructive button and Cancel.
