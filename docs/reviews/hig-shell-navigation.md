# App shell and navigation: HIG review (2026-09-28)

Reviewed against the live HIG with the `apple-hig` skill, `--platform ios`.

**Pages read:** `designing-for-ios`, `designing-for-ipados`, `tab-bars`, `toolbars`, `searching`,
`search-fields`, `sidebars`, `split-views`, `modality`, `sheets`, `alerts`, `action-sheets`,
`popovers`, `layout`, `mac-catalyst`, `loading`, `launching`, plus `accessibility`, `voiceover`,
`buttons`, `feedback`, `progress-indicators`, `ratings-and-reviews` and `keyboards` where the code
needed them.

**Scope.** Code read: `Core/TabBar/`, `Core/AppView/`, `Core/Search/`, `Root/DialedInApp.swift`,
`Root/LaunchScreen.storyboard`, `Root/RIBs/` (`GlobalRouter`, `CoreRouter`, `CoreBuilder`,
`ReportFlow`), `Components/Modals/`, `Components/DesignSystem/Presentation.swift` and
`BottomCTA.swift`, the two tab accessory views, and every `showScreen`, `showModal`, `showAlert`,
`showLoadingModal`, `navigationBarBackButtonHidden` and `ToolbarItem` call site across `Core/`.
The router's own behaviour was read from the pinned SwiftfulRouting checkout (0.2.2, `99a96ae`).
`Core/AdaptiveMain/` no longer exists.

**Not reviewed.** `Root/Dependencies/`, the content of individual screens, onboarding's own
modals and hidden back buttons (covered in `onboarding-hig-review.md`), the widget.

**Not checked.** This is a code review. Nothing was built or run, so Dark Mode, large text,
VoiceOver, iPad and Mac Catalyst are all unverified. Anything that depends on runtime behaviour
says so.

Paths are relative to `DialedIn/`. Findings are most serious first.

## Resolution (2026-09-28, branch hig/shell)

| # | Status | What changed |
|---|---|---|
| 1 | fixed | Already non-dismissible with a label and modal trait on `feature/hig`; the spinner now also sits on a glass panel instead of white on dimmed grey. Nav and tab bar staying tappable above it is still unverified. |
| 2 | needs a change elsewhere | The three read-only uses are in Notifications, Dashboard and Training presenters. |
| 3 | skipped: decision | Title already says "Compound" (and the `CustomModalView` preview now does too). System prompt vs App Store link awaits a decision. |
| 4 | fixed (shell part) | Titles translated, empty button hidden, scrolling: already fixed. The warm-up explanation is now a system alert. Health Disclaimer and Set Rest live in feature folders; `CustomModalView` stays until they and the rating card move. |
| 5 | needs a change elsewhere | New `GlobalRouter.showDiscardChangesDialog(onDiscard:)` for the per-screen close buttons; the `interactiveDismissDisabled` flags belong to each screen. |
| 6 | skipped: decision | |
| 7 | needs a change elsewhere | Workout tracker is under `Core/Training/`. |
| 8 | fixed (shell part) | Active-workout prompt and the new shared draft-meal prompt are action sheets; Search's draft-meal choice uses it. Report is one `.half` sheet with Close/Send. Invite code is a small sheet. Other pickers and forms are in feature folders. |
| 9 | fixed (shell part) | `showAlert(title:error:)` added; the message is the app's own `errorDescription` or "Please try again."; bare `showAlert(error:)` now titles "Something Went Wrong". The 32 call sites still need their own titles. |
| 10 | fixed (shell part) | First failure raises a persistent "Can't reach the server" toast, cleared on success; retries back off 5 s to 60 s. Welcome's in-button spinner is in onboarding. |
| 11 | needs a change elsewhere | `Root/LaunchScreen.storyboard` is outside this branch's paths. |
| 12 | needs a change elsewhere | Gym Profile and Program Design. |
| 13 | skipped: decision | |
| 14 | fixed | Announced to VoiceOver, failure toasts stay until tapped, swipe up dismisses, banner opens Notifications, one stacked overlay. Toast-behind-sheet is unchanged (root overlay). |
| 15 | skipped: decision | |
| 16 | fixed (shell part) | "Report Sent" is a success toast. Integrations and Timeline actions are elsewhere. |
| 17 | needs a change elsewhere | Add Meal and Progress Photos. |
| 18 | fixed | `peopleSearchFailed` with an `InlineMessage`; Clear has a 44 pt target. |
| 19 | fixed | Selected tab restored from `@SceneStorage` by `DeepLink.Tab.rawValue`. On the way: selection was keyed by translated title, so in Spanish links and push taps selected nothing and the Search label stayed English (own `[Fix]` commit). |
| Smaller | partly fixed | Draft-meal wording fixed in Search and in the shared prompt; "Enter Invite Code" capitalised; Dashboard badge counts only comments, mentions and follow requests. Cancel roles, other capitalisation and Licences are elsewhere. |

## Findings

### 1. The "blocking" loading modal can be tapped away, and says nothing to VoiceOver
Severity: hurts usability
Where: `Root/RIBs/GlobalRouter.swift:85-94`; 12 call sites, including
`Core/Onboarding/2 - AuthView/AuthPresenter.swift:43`, `:85`, `:128`,
`Core/Training/Subviews/WorkoutSessionDetailView/WorkoutSessionDetailPresenter.swift:211`,
`Core/Notifications/NotificationsPresenter.swift:216`
Guideline: "Keep progress indicators moving so people know something is continuing to happen…
If a process stalls for some reason, provide feedback that helps people understand the problem"
and "If it's helpful, display a description that provides additional context for the task." —
https://developer.apple.com/design/human-interface-guidelines/progress-indicators. "Inform
VoiceOver when visible content or layout changes occur." —
https://developer.apple.com/design/human-interface-guidelines/voiceover
What happens: `showLoadingModal()` passes a background colour and nothing else, and the router's
`showModal` defaults `dismissOnBackgroundTap` to `true`. A tap anywhere on the dimmed area removes
the spinner while the save or sign-in is still running, and the screen underneath is live again.
The later `dismissModal()` then has nothing to dismiss. The spinner has no label, and the router
draws modals as a SwiftUI `.overlay` with no `.isModal` trait, so VoiceOver can still reach the
content behind it. The spinner is white on 30% black, which over a light screen is white on light
grey (my judgment, not run).
Fix:
```swift
func showLoadingModal() {
    router.showModal(
        transition: .opacity,
        backgroundColor: .black.opacity(0.3),
        dismissOnBackgroundTap: false,
        destination: {
            ProgressView()
                .controlSize(.large)
                .padding(Spacing.xl)
                .glassEffect(.regular, in: .rect(cornerRadius: Radius.l, style: .continuous))
                .accessibilityLabel("Loading")
                .accessibilityAddTraits(.isModal)
        }
    )
}
```
Unverified: because the overlay hangs off the screen's own router view, the navigation bar and
tab bar probably stay tappable above it. Check on a device.
Size: S
Decision needed: no

### 2. The loading modal also covers reads, where the HIG asks for content first
Severity: hurts usability
Where: `Core/Notifications/NotificationsPresenter.swift:216` (every notification tap),
`Core/Dashboard/WorkoutSessionRow/WorkoutSessionRowPresenter.swift:179`,
`Core/Training/Subviews/WorkoutSessionDetailView/WorkoutSessionDetailPresenter.swift:471`
Guideline: "Show something as soon as possible… consider showing placeholder text, graphics, or
animations as content loads" and "Let people do other things in your app or game while they wait
for content to load." — https://developer.apple.com/design/human-interface-guidelines/loading
What happens: tapping a notification dims the whole screen behind a spinner until the session,
profile, share or challenge has been fetched, then opens the destination. `CONTRACT.md` reserves
the modal for blocking writes, so these three are outside the contract as well.
Fix: open the destination at once and let it load itself with `.redacted(reason: .placeholder)`,
as the contract's Loading row says. For the two share-image renders, put the spinner in the
button that was tapped.
Size: M
Decision needed: no

### 3. The rating prompt asks "Are you enjoying AIChat?"
Severity: hurts usability
Where: `Root/RIBs/Core/CoreBuilder.swift:24`; shown from `Core/Profile/ProfilePresenter.swift:160`
Guideline: "Prefer the system-provided prompt. iOS, iPadOS, and macOS offer a consistent,
nonintrusive way for apps and games to request ratings and reviews." —
https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews. "In
informational alerts only, you can use 'OK' for acceptance, avoiding 'Yes' and 'No.'" —
https://developer.apple.com/design/human-interface-guidelines/alerts
What happens: the Profile's rating row opens a custom card that names the template project, with
"Yes" and "No" buttons, before the system prompt. The preview in `CustomModalView.swift:74` says
"Dialed". The app is called Compound.
Fix: delete `showRatingsModal` and `ratingsModal`, and call
`AppStoreRatingsHelper.requestRatingsReview()` straight from `onRatingsButtonPressed()`. My
judgment: the system prompt is rate-limited and may show nothing on a tap, so a row the user taps
deliberately is better served by the App Store's write-review URL.
Related: "DialedIn" is still in user-facing copy at `Core/Notifications/NotificationsView.swift:87`
and `Core/Onboarding/5 - HealthDisclaimer/HealthDisclaimerRouter.swift:32`.
Size: S
Decision needed: yes — system prompt, App Store link, or both

### 4. `CustomModalView` is a hand-built alert that misses what the system alert gives for free
Severity: hurts usability
Where: `Components/Modals/CustomModalView.swift:22-66`; callers `Root/RIBs/Core/CoreRouter.swift:16-32`,
`Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerRow/SetTrackerRowRouter.swift:21-55`,
`Core/Onboarding/5 - HealthDisclaimer/HealthDisclaimerRouter.swift:20-40`, and the notifications
modal already reported in the onboarding review
Guideline: "Always give people an obvious way to dismiss a modal view. In general, it works well
to follow the platform conventions people already know." —
https://developer.apple.com/design/human-interface-guidelines/modality. "Be prepared for
text-size changes… Apps that don't respond to this setting can be difficult or impossible to use"
— https://developer.apple.com/design/human-interface-guidelines/layout. "Add labels to any custom
elements your app defines." — https://developer.apple.com/design/human-interface-guidelines/voiceover
What happens, four separate problems:
- **Button titles are never translated.** `primaryButtonTitle` and `secondaryButtonTitle` are
  `String`, so `Text(primaryButtonTitle)` at `:44` and `:51` does no catalog lookup. "Got it",
  "Save", "Cancel", "Yes", "No", "I Agree & Continue" and "Go Back" stay English in Spanish. The
  Health Disclaimer subtitle at `HealthDisclaimerRouter.swift:27-33` is a raw literal too.
- **The warm-up modal has an invisible second button.** `CoreRouter.swift:28` passes
  `secondaryButtonTitle: ""`. The view still draws the padded, tappable `Text("")` at `:51-59`,
  so there is an empty hit area under "Got it" and an unlabelled button for VoiceOver.
- **Nothing scrolls.** The card is a plain `VStack`. The Health Disclaimer text is about sixty
  words, so at accessibility sizes the card grows past the screen and the buttons go with it
  (not run).
- **No modal trait, no swipe, no Escape.** See finding 1 for the overlay.
Fix: use the system components. The warm-up explanation and the Health Disclaimer confirmation
become `router.showAlert` (two buttons, scrolls by itself, localised through
`String(localized:)`). "Set Rest" holds two wheel pickers and becomes a sheet with
`.sheetConfig(config: .compact)`, `role: .close` and `role: .confirm`. Then delete
`CustomModalView`.
If it stays: make both titles `LocalizedStringKey`, make the secondary button optional, wrap the
text in a `ScrollView`, cap the width for iPad, and add `.accessibilityAddTraits(.isModal)`.
Size: M
Decision needed: no

### 5. Typed input is lost without a warning when a form is closed or swiped away
Severity: hurts usability
Where: `Core/Nutrition/Foods/CreateFood/CreateFoodPresenter.swift:71` (sheet, `CreateFoodView.swift:211`),
`Core/Challenges/CreateChallenge/CreateChallengePresenter.swift:102` (sheet),
`Core/Training/Subviews/AddTraining/CreateExercise/CreateExercisePresenter.swift:92` (cover),
`Core/Nutrition/Recipes/CreateRecipe/CreateRecipePresenter.swift:49` (cover),
`Core/Training/Subviews/WorkoutSessionDetailView/WorkoutSessionDetailPresenter.swift:126-141`
(sheet, `WorkoutSessionDetailView.swift:241`)
Guideline: "When necessary, help people avoid data loss by getting confirmation before closing a
modal view. Regardless of whether people use a dismiss gesture or a button" —
https://developer.apple.com/design/human-interface-guidelines/modality. "If people have unsaved
changes in the sheet when they begin swiping to dismiss it, use an action sheet to let them
confirm their action." — https://developer.apple.com/design/human-interface-guidelines/sheets
What happens: the four create flows call `router.dismissScreen()` directly from the close button.
`interactiveDismissDisabled` appears nowhere in the app or in the router package, so every sheet
can also be swiped away. That includes Workout Session Detail in edit mode, which has a
"Discard changes?" prompt on its close button that the swipe goes straight past.
Fix: each presenter exposes `hasUnsavedChanges`. The view adds
`.interactiveDismissDisabled(presenter.hasUnsavedChanges)`, so the swipe is refused while there
is something to lose, and the close button calls one presenter method that shows
`router.showConfirmationDialog` with "Discard Changes" (destructive) and "Keep Editing" when the
flag is set. With nothing typed, both dismiss at once as they do today.
Size: M
Decision needed: no

### 6. Sheets open sheets, three deep
Severity: hurts usability
Where, three confirmed chains:
- Analytics → Body Metrics (`Core/Analytics/Subviews/BodyMetrics/BodyMetricsView.swift:110`) →
  measurement detail (`…/MeasurementDetails/BodyMeasurementDetail.swift:142`) → Log Measurement
  (`…/LogMeasurement/LogMeasurementView.swift:128`)
- Profile (`Core/Profile/ProfileView.swift:206`) → Gym Profile → Edit Band
  (`…/GymProfile/EditBand/EditBandView.swift:110`) → Add Band (`…/AddBand/AddBandView.swift:105`)
- Notifications (`Core/Notifications/NotificationsView.swift:240`) → Workout Session Detail
  (`WorkoutSessionDetailView.swift:241`) → Comments (`Root/RIBs/Core/CoreRouter.swift:41`)

All 19 destinations opened from `Core/Analytics/AnalyticsPresenter.swift:130-206` are `.sheet`.
In total the app has 98 sheet presentations (88 through the router, 10 native) against 104
pushes.
Guideline: "Display only one sheet at a time from the main interface… If closing a sheet takes
people back to another sheet, they can lose track of where they are in your app." —
https://developer.apple.com/design/human-interface-guidelines/sheets. "Present content modally
only when there's a clear benefit" and "Take care to avoid creating a modal experience that feels
like an app within your app." — https://developer.apple.com/design/human-interface-guidelines/modality.
On iPad: "minimizing modal interfaces and full-screen transitions" —
https://developer.apple.com/design/human-interface-guidelines/designing-for-ipados
What happens: a chart card is a drill-down into the hierarchy, not a scoped task, but it opens
as a sheet that covers the tab bar. Its children open as further sheets on top.
Fix: push anything that is reading or browsing (the Analytics details, Body Metrics, Exercise
Analytics, Workout History, the Edit equipment screens). Keep sheets for the leaf tasks that
collect input (Log Weight, Log Measurement, Add Band). After that no chain is deeper than one.
Size: L
Decision needed: yes — Analytics details as pushes is a visible navigation change

### 7. The workout tracker has no visible way out
Severity: hurts usability
Where: `Core/Training/Subviews/WorkoutTracker/WorkoutTrackerView.swift:196-236`, presented at `:260`
Guideline: "Always give people an obvious way to dismiss a modal view… in iOS, iPadOS, and
watchOS apps, people typically expect to find a button in the top toolbar or swipe down" —
https://developer.apple.com/design/human-interface-guidelines/modality
What happens: the tracker is a full-screen cover, so it cannot be swiped down, and its toolbar
holds one item, a More menu. "Minimize Tracker" is the first row inside that menu. README
decision 3 keeps Finish Workout in the menu; it says nothing about Minimize.
Fix: add the contract's dismiss button and leave the menu as it is.
```swift
ToolbarItem(placement: .cancellationAction) {
    Button(role: .close) { presenter.minimizeSession() }
        .accessibilityLabel("Minimize workout")
}
```
Also: `:261` builds the view with `try?`, and the presenter throws when there is no active
session. That would present an empty cover with no controls at all. I could not confirm a path
that reaches it (my judgment); guard in `showWorkoutTrackerView()` and show an alert instead.
Size: S
Decision needed: no

### 8. Alerts are used as pickers and as forms
Severity: hurts usability
Where: pickers — `Core/Training/TrainingPresenter.swift:175` (one button per session),
`Core/Training/Subviews/ExerciseSettings/ExerciseSettingsPresenter.swift:81`,
`Core/Profile/Subviews/NutritionSettings/FoodLogSettings/FoodLogSettingsPresenter.swift:134`,
`Core/Training/Subviews/WorkoutTracker/ExerciseTracker/SetTracker/SetTrackerPresenter.swift:243`, `:267`,
`Root/RIBs/GlobalRouter.swift:60`,
`Core/Training/Subviews/WorkoutTemplateDetail/WorkoutTemplateDetailPresenter.swift:98`,
`Core/Training/Subviews/ActiveTrainingProgram/ActiveTrainingProgramPresenter.swift:214`,
`Core/Search/SearchPresenter.swift:306`, `Core/Dashboard/DashboardPresenter.swift:368`.
Forms — `Root/RIBs/ReportFlow.swift:60`, `:117`, `Core/Search/SearchView.swift:63`.
`showConfirmationDialog` exists and has one caller; `showAlert` with buttons has 47.
Guideline: "Use an action sheet — not an alert — to offer choices related to an intentional
action… an alert is usually unexpected, generally telling people about a problem" —
https://developer.apple.com/design/human-interface-guidelines/action-sheets. "alerts display a
title, optional informative text, and up to three buttons" and "include a text field only if you
need people's input to resolve the situation." —
https://developer.apple.com/design/human-interface-guidelines/alerts
What happens: choosing a weight unit, a timestamp side or one of today's sessions is presented
as an alert. The report flow is two alerts in a row: four reasons with **no Cancel button**
(`ReportFlow.swift:64-70`), then a text field. Someone who taps Report by mistake has to pick a
reason to get out.
Fix:
- Choices that follow an action (Resume / Discard & Start New, Display Only / Convert Values,
  the draft-meal choice, the session picker): change the call to `router.showConfirmationDialog`.
  The buttons stay as they are.
- Settings values (Weight Unit, Timestamp Side): a `Picker` or `Menu` in the row, no presentation.
- Report and invite code: a `.compact` sheet with the reason list, the note field, `role: .close`
  and `role: .confirm`.
Size: M
Decision needed: no

### 9. Thirty-two error alerts are titled "Error"
Severity: hurts usability
Where: `Root/RIBs/GlobalRouter.swift:40`, reached from 32 `showAlert(error:)` call sites, for
example `Core/Profile/Subviews/Account/AccountPresenter.swift:53`, `:209`, `:255`,
`Core/Nutrition/NutritionPresenter.swift:206`, `:227`, `:244`,
`Core/Notifications/NotificationsPresenter.swift:82`, `:125`, `:138`, `:323`, `:387`,
`Core/Paywalls/Paywall/PaywallPresenter.swift:70`, `:126`, `:155`,
`Core/Analytics/Subviews/BodyMetrics/LogMeasurement/LogWeightView/LogWeightPresenter.swift:77`
Guideline: "Avoid writing a title that doesn't convey useful information — like 'Error' or
'Error 329347 occurred'… describe what happened, the context in which it happened, and why." —
https://developer.apple.com/design/human-interface-guidelines/alerts
What happens: the title is "Error" and the message is `error.localizedDescription`, which for a
Firebase or URL error is developer text. The `showSimpleAlert` call sites already do this well
("Unable to Save Settings", "Unable to Delete Entry").
Fix: give the helper the context and drop the raw description.
```swift
func showAlert(_ title: String, error: Error)   // "Unable to Save Weight"
```
with `subtitle` "Please try again." unless the error is a `LocalizedError` the app itself threw.
Migrate the 32 sites; the offline branch stays.
Size: M
Decision needed: no

### 10. A first launch without a connection fails silently
Severity: hurts usability
Where: `Core/AppView/AppPresenter.swift:51-89`,
`Core/Onboarding/0 - WelcomeView/WelcomeView.swift:58`
Guideline: "If your app detects a problem at startup, like no network connection, consider
alternative ways to let people know. For example, you could show cached or placeholder data and a
nonintrusive label that describes the problem." —
https://developer.apple.com/design/human-interface-guidelines/alerts. "If you make people wait
for loading to complete before displaying anything, they can interpret the lack of content as a
problem with your app" — https://developer.apple.com/design/human-interface-guidelines/loading
What happens: when anonymous sign-in or `logIn` throws, `checkUserStatus()` logs it, sleeps five
seconds and calls itself, for ever. Meanwhile the Welcome screen's only button is disabled until
`currentUser` exists. The person sees a greyed-out "Get Started" with no spinner and no reason.
Fix: expose `isConnecting` and `connectionFailed` on `AppPresenter`. Welcome passes
`isLoading:` to its `CallToActionButton` while connecting and shows
`InlineMessage(.warning, "Can't reach the server. Check your connection.")` above it after the
first failure. Keep the retry, but back it off.
Size: M
Decision needed: no

### 11. The launch screen is a splash screen
Severity: polish
Where: `Root/LaunchScreen.storyboard:18` (full-bleed `SplashScreen` image), `:23` ("COMPOUND" in
40 pt Arial Bold Italic), `:32` (fixed white background)
Guideline: "Design a launch screen that's nearly identical to the first screen of your app",
"Avoid including text on your launch screen", "don't include logos or other branding elements
unless they're a fixed part of your app's first screen" and "make sure that your launch screen
matches the device's current orientation and appearance mode." —
https://developer.apple.com/design/human-interface-guidelines/launching
What happens: a returning user goes from a white branded image to the Dashboard. In Dark Mode
that is a white flash before a dark screen.
Fix: replace the storyboard's contents with a single view whose background is
`systemGroupedBackground`, which is what `Color.canvas` resolves to. No image, no label. The
Welcome screen already carries the brand for new users.
Size: S
Decision needed: no

### 12. Two screens replace the system back button with a drawn chevron
Severity: polish
Where: `Core/Profile/Subviews/TrainingSettings/GymProfiles/GymProfile/GymProfileView.swift:94`, `:323-330`;
`Core/Training/Subviews/AddTraining/CreateProgram/ProgramDesign/ProgramDesignView.swift:55`, `:203-211`
Guideline: "Use the standard Back and Close buttons… If you create a custom version of either,
make sure it still looks the same, behaves as people expect" —
https://developer.apple.com/design/human-interface-guidelines/toolbars. "it's especially
important let people swipe to navigate back" —
https://developer.apple.com/design/human-interface-guidelines/designing-for-ios
What happens: both hide the back button so that going back can save or ask to discard. That also
removes the edge swipe and the long-press back menu. The two chevrons differ
(`chevron.backward` and `chevron.left`; the second does not flip for right-to-left).
Fix: keep the system button. Gym Profile saves on every edit or in `onDisappear`, and an unnamed
profile is simply not saved. Program Design is a create flow, so it takes the contract's
`role: .close` with the discard confirmation from finding 5.
Size: M
Decision needed: no

### 13. The tab bar accessory ignores its inline placement and has two lines in a fixed height
Severity: polish
Where: `Core/TabBar/TabBarView.swift:75-100`,
`Core/Training/Components/TrainingAccessory/TrainingAccessoryView.swift:21-41`, `:76`,
`Core/Nutrition/Components/MealAccessory/MealAccessoryView.swift:20-41`, `:58-62`, `:80`
Guideline: "you can choose to minimize the tab bar and move the accessory inline with it when a
person scrolls down" — https://developer.apple.com/design/human-interface-guidelines/tab-bars
(which links `TabViewBottomAccessoryPlacement`). "table rows or other containers may need to
grow in height so that text isn't cropped" —
https://developer.apple.com/design/human-interface-guidelines/layout
What happens: `.tabBarMinimizeBehavior(.onScrollDown)` is on, but neither accessory reads
`tabViewBottomAccessoryPlacement`. Inline, the same two text lines, 16 pt padding and up to five
38 pt circles have to fit between the minimised tab and the search button. The code comment at
`TrainingAccessoryView.swift:75` already notes the height is fixed, so two lines of
`.subheadline` will clip at large text sizes (not run). Three smaller things:
- With a workout and a draft meal both open, the second sits off-screen in a horizontal scroll
  view with hidden indicators. Nothing shows it is there.
- The meal accessory's title is a bare time ("12:30") and its timer says "Elapsed". Neither says
  this is a draft meal.
- Every meal item draws the `SplashScreen` image (`MealAccessoryView.swift:59`).
Fix: read the placement and drop to one line and no thumbnails when it is `.inline`. Give each
button one label, "Resume workout, Push Day, 12 minutes" and "Continue draft meal, 2 items".
Show only the workout when both exist; the draft meal is reachable from Nutrition.
Size: M
Decision needed: yes — what to show when a workout and a draft meal are both open

### 14. Toasts and banners vanish after four seconds and are never announced
Severity: polish
Where: `Core/AppView/AppPresenter.swift:91-110`, `Core/AppView/AppView.swift:58-73`,
`Core/AppView/AppToastView.swift:34-50`, `Core/AppView/ActivityNotificationBannerView.swift:41-60`
Guideline: "Minimize use of time-boxed interface elements. Views and controls that auto-dismiss
on a timer can be problematic for people who need longer to process information… Prefer
dismissing views with an explicit action." —
https://developer.apple.com/design/human-interface-guidelines/accessibility. "Make sure all
feedback is accessible." — https://developer.apple.com/design/human-interface-guidelines/feedback
What happens: the failure toast carries the one instruction that matters ("It's still on this
device — resume it from Training") and leaves after four seconds. No
`AccessibilityNotification.Announcement` is posted for either view. The activity banner looks
tappable and is not. The two overlays share one position, so they draw on top of each other if
both fire.
Fix: in `onAppToast` and `onNewActivityNotification`, post
`AccessibilityNotification.Announcement(message).post()`. Keep `.failure` toasts until tapped,
and let a swipe up dismiss any of them. Make the banner a button that opens Notifications. Put
both in one `VStack` inside a single overlay.
My judgment, not run: the overlay is on the root view, so a toast raised while a sheet or cover
is up appears behind it.
Size: S
Decision needed: no

### 15. No keyboard shortcuts or menu commands for iPad and Mac
Severity: polish
Where: `Root/DialedInApp.swift:26-36` (no `.commands`); `keyboardShortcut` appears nowhere in
the app
Guideline: "Make sure people retain access to important tab-bar items in the Mac version of your
app… be sure to give people quick access to top-level items by listing them in the macOS View
menu." and "On the Mac, people expect apps to offer both keyboard navigation and shortcuts." —
https://developer.apple.com/design/human-interface-guidelines/mac-catalyst
What happens: Mac Catalyst is enabled on the app target, and iPad supports hardware keyboards,
but there is no way to switch tab, search, or start a log from the keyboard.
Fix: a `Commands` block on the `WindowGroup` with Command-1 to Command-4 for the tabs and
Command-F for Search, each posting the existing `DeepLink.tab(…).post()`.
The same page also says an app whose essential features need HealthKit "might not be suitable
for the Mac". README follow-up decision 7 records that the Catalyst build was already broken.
Size: S
Decision needed: yes — is the Mac version shipping, or should Catalyst be turned off

### 16. Alerts that only inform
Severity: polish
Where: `Root/RIBs/ReportFlow.swift:100` ("Report Sent"),
`Core/Profile/Subviews/GeneralSettings/Integrations/IntegrationsPresenter.swift:49` ("Upload
Successful"), `Core/Nutrition/TimelineActions/TimelineActionsPresenter.swift:57`, `:102`
("Nothing to copy", "Nothing to clear")
Guideline: "Avoid using an alert merely to provide information. People don't appreciate an
interruption from an alert that's informative, but not actionable." —
https://developer.apple.com/design/human-interface-guidelines/alerts
Fix: the first two become `interactor.showAppToast(AppToast(style: .success, …))`. For the last
two, disable Copy and Clear when the day has no meals.
Size: S
Decision needed: no

### 17. Toolbar crowding and a text button beside a symbol
Severity: polish
Where: `Core/Nutrition/MealLog/AddMeal/AddMealView.swift:243-289` (five items: close, a two-line
date button, a calorie readout, a row of thumbnails with `maxWidth: .infinity`, a chevron);
`Core/Analytics/Subviews/BodyMetrics/ProgressPhotos/ProgressPhotosView.swift:78-94` ("Compare"
next to the Add menu, no spacer); `:73` puts the close button in `.topBarLeading` where the
contract asks for `.cancellationAction`
Guideline: "Choose items deliberately to avoid overcrowding", "Prefer using standard components
in a toolbar" and "Keep actions with text labels separate. Placing an action with a text label
next to an action with a symbol can create the illusion of a single action" —
https://developer.apple.com/design/human-interface-guidelines/toolbars
Fix: in Add Meal, keep close and the picker button in the toolbar and move the time, the
calories and the thumbnails into the first section of the content. In Progress Photos, add
`ToolbarSpacer(.fixed, placement: .topBarTrailing)` between the two items.
Size: S
Decision needed: no

### 18. Search: a failed people search reads as "no results"
Severity: polish
Where: `Core/Search/SearchPresenter.swift:132`, `Core/Search/SearchView.swift:37-39`, `:139-142`
Guideline: "Show people when a command can't be carried out and help them understand why." —
https://developer.apple.com/design/human-interface-guidelines/feedback. "a button needs a hit
region of at least 44x44 pt" — https://developer.apple.com/design/human-interface-guidelines/buttons
What happens: `try?` turns a network failure into an empty list, so the screen shows "No Results
for …" when the truth is that people could not be searched. The "Clear" button in the Recent
header uses `.font(.label)` inside a section header; its height was not measured but a caption
in a header is unlikely to reach 44 pt.
Fix: keep a `peopleSearchFailed` flag and show
`InlineMessage(.warning, "Couldn't search people. Check your connection.")` in the People
section. Give Clear `.frame(minHeight: ControlSize.row)` and `.contentShape(.rect)`.
Size: S
Decision needed: no

### 19. Nothing is restored on relaunch
Severity: polish
Where: `Core/TabBar/TabBarPresenter.swift:40`; `SceneStorage` appears nowhere in the app
Guideline: "Restore the previous state when your app restarts so people can continue where they
left off." — https://developer.apple.com/design/human-interface-guidelines/launching
What happens: the app always opens on Dashboard with every stack at its root.
Fix: persist the selected tab by `DeepLink.Tab.rawValue` in `@SceneStorage` in `TabBarView` and
hand it to the presenter on appear. Not by title: `selectedTabTitle` holds a localised string.
Size: S
Decision needed: no

## Smaller items

- Alert wording. "You already have an draft meal." at `Core/Search/SearchPresenter.swift:308`,
  `Core/Dashboard/DashboardPresenter.swift:370` and
  `Core/Analytics/Subviews/InsightsAndAnalytics/EnergyBalance/EnergyBalancePresenter.swift:45`.
  The button beside it, "Delete drafted meal", opens a new meal and deletes nothing at that
  point; "Start New Meal" says what it does.
- Alert capitalisation is mixed: "Unable to add" (15 sites), "Unable to save", "Discard
  changes?", "Enter invite code", "Continue editing" beside "Unable to Save Settings". The alerts
  page asks for title-style capitalisation in fragment titles and in every button.
- `Button("Cancel") { }` without `role: .cancel` at
  `Core/Onboarding/2 - AuthView/AuthPresenter.swift:66`, `:107` and
  `Core/Onboarding/4 - CompleteAccountSetup/9 - Expenditure/ExpenditurePresenter.swift:245`, so
  it is drawn as an ordinary action and Escape does not reach it.
- The Dashboard badge (`Core/TabBar/TabBarPresenter.swift:27`) counts likes as well as follow
  requests. The tab bars page says to "Reserve badges for critical information". My judgment:
  count requests, comments and mentions only.
- `Core/Profile/Subviews/About/Licences/LicencesView.swift:81` presents a page of text as a
  full-screen cover. A push does the same job inside the Profile sheet.

## Contract conflicts

- **Loading.** `CONTRACT.md` § Patterns says "Blocking writes: `router.showLoadingModal`". The
  HIG does not forbid a blocking indicator, but it points the other way in three places: "Let
  people do other things in your app or game while they wait"
  (https://developer.apple.com/design/human-interface-guidelines/loading), "When it's feasible,
  let people halt processing" (https://developer.apple.com/design/human-interface-guidelines/progress-indicators)
  and "Configure a button to display an activity indicator when you need to provide feedback
  about an action that doesn't instantly complete"
  (https://developer.apple.com/design/human-interface-guidelines/buttons). `CallToActionButton`
  and the `role: .confirm` pattern already have an in-button spinner. Findings 1 and 2 are about
  how the modal is built and where it is misused, not about this rule.
- **Titles.** The contract makes every non-root screen `.inline`. The toolbars page says, for
  iOS, "Use a large title to help people stay oriented as they navigate and scroll"
  (https://developer.apple.com/design/human-interface-guidelines/toolbars). It does not say every
  screen, so this is a difference of emphasis, recorded for completeness.

## Done well — keep

- One `TabView` for every width with `.sidebarAdaptable`, five single-word labels, a real
  `Tab(role: .search)`, and deep links routed through one presenter.
- Layout follows size class. `UIScreen.main` and `userInterfaceIdiom` appear nowhere.
- Search is one place for everything, its prompt names the scope, results are grouped, recents
  are only written on commit and can be cleared, and the empty state is
  `ContentUnavailableView.search`.
- `Button(role: .close)` at 78 sites and `role: .confirm` at 34, in `.cancellationAction` and
  `.confirmationAction`. No drawn close buttons, no "Done" on its own.
- Every sheet preset includes `.large` and shows the grabber. No popovers, so none in compact.
- Destructive alerts name the action ("Discard", "Delete") and carry a Cancel.
- Toast and banner transitions fall back to opacity under Reduce Motion.
- iPhone is portrait only and iPad supports all four orientations.
