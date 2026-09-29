# Dashboard, social feed, challenges, sharing and notifications: HIG review (2026-09-28)

Reviewed against the live HIG with the `apple-hig` skill, `--platform ios`.

**Pages read.** `designing-for-ios`, `notifications`, `managing-notifications`, `activity-views`,
`collaboration-and-sharing`, `ratings-and-reviews`, `lists-and-tables`, `collections`, `loading`,
`images`, `image-views`, `privacy`, `feedback`, `buttons`, `menus`, `context-menus`, `alerts`,
`accessibility`, `writing`, `healthkit`, plus `sheets`, `modality`, `action-sheets`,
`progress-indicators`, `layout` and `settings`, which the code turned out to need.

**Scope.** All of `Core/Dashboard/`, `Core/Challenges/`, `Core/Sharing/`, `Core/Notifications/`,
`Components/Views/User/`, `Components/Views/Profile/ProfileButton.swift`, `Managers/Push/`, and the
shared code those screens run through: `Root/RIBs/ReportFlow.swift`, `FollowFlow.swift`,
`GlobalRouter.swift`, the `UNUserNotificationCenterDelegate` in `Root/AppDelegate.swift`,
`Managers/Training/ReviewPrompt.swift`, `Managers/Invites/CoreInteractor+Invites.swift`,
`Components/Views/DashboardCard.swift`, `ActivityRingView.swift`, `SectionHeaderView.swift`, and
the push payloads in `functions/lib.js`.

**Not reviewed.** The share cards' drawing (`WorkoutShareCardView`, `WeeklyReviewShareCardView`):
exempt, only their share flow was read. `TodaysWorkoutCard` and `WorkoutSessionDetailView` belong
to the training review; they were read only where the Dashboard or Notifications present them.
People search lives on the Add tab and was not read.

**Not checked.** This is a code review. Nothing was built or run, so Dark Mode, the largest text
sizes, VoiceOver, iPad and Mac Catalyst are all unverified. Findings 3 and 4 are read from layout
code and need a run to confirm the exact result.

**Tree state.** `Managers/Push/PushManager.swift` was being edited by someone else while this was
written (the rest timer now asks for notification permission). Line numbers are from the working
tree at the time of writing. The SwiftfulRouting and SwiftfulUtilities sources were read from a
DerivedData checkout, not from this worktree.

Paths are relative to `DialedIn/` unless they start with `functions/`. Findings are most serious
first.

## Resolution (2026-09-28, branch hig/dashboard)

| Finding | Status | What changed |
|---|---|---|
| 1 | skipped: decision | Come-back/meal-reminder scheduling lives in `Managers/Push/`, not owned here. |
| 2 | not a problem | Already a `.sheetConfig(config: .half)` sheet with Cancel via `role: .close`, and "Report sent" already raises a toast, not an alert. Verified against current code — no change needed. |
| 3 | fixed | `DashboardView` sizes the carousel from `@ScaledMetric` `carouselContentHeight` (based on `DashboardCard.contentHeight`) instead of the static value, so the outer scroll container grows with Dynamic Type. `NutritionCard` stacks the ring above the macro bars at accessibility sizes via `AdaptiveStack`. `ActivityRingView`/`DashboardCard` (Components/Views/, not owned) already scale — verified, no change needed there. |
| 4 | fixed | 44pt hit targets: Comments (like, cancel-reply, send, new Reply button), SocialProfile (weekly-goal button, Followers/Following stats, See All), WorkoutSessionRow footer (like/comment/share/more — frame moved onto the labels), CircleActivityStripView (Nudge/Set goal, dropped `.controlSize(.mini)`), CircleWeeklySummaryCard/InviteFriendCard/UsernameBannerView close buttons, WeeklyReviewView's prev/next chevrons, ChallengesDashboardSection's New button. `Components/Views/User/UserRowView.swift` and `Components/Views/SectionHeaderView.swift` are outside `Components/Views/` ownership here — see Needs a change elsewhere. |
| 5 | fixed | Comments, SocialProfile (sessions) and Notifications now keep a `loadFailed` flag instead of discarding the error, and show `ContentUnavailableView` with a Try Again button instead of a false empty state. |
| 6 | fixed | Comments: visible "Reply" text button under each comment; swipe actions moved to `.rowActions` so Delete/Report also appear in a context menu. FollowersList's Remove moved to `.rowActions` too. |
| 7 | skipped: decision | Notifications-as-sheet vs pushed screen is unresolved. |
| 8 | skipped: decision | Settings-screen location (here vs Profile) is unresolved. |
| 9 | fixed | `NotificationsPresenter` only shows the full-screen spinner before the first successful load (`hasLoadedOnce`); pull-to-refresh no longer tears the list down. |
| 10 | needs a change elsewhere | `Root/AppDelegate.swift:134-140`, not owned. |
| 11 | skipped: decision | Interruption levels/badges are unresolved and live in `functions/`/`Managers/Push/`, not owned. |
| 12 | needs a change elsewhere | `functions/lib.js` and `Managers/Push/PushManager.swift`, not owned. The eight notification row titles in `NotificationsView.swift` are localized and cleaned up (title case, no emoji) as far as this area's files allow. |
| 13 | skipped: decision | Share button primary (link vs image) is unresolved. |
| 14 | fixed (within owned folders) | Alert titles say what failed and are title-cased throughout Dashboard/Challenges/Notifications/Sharing; the draft-meal picker-as-alert now uses `showDraftMealDialog`; the comment delete alert now has an explicit Cancel; "Saved to your workouts" is a toast, not an alert. `Root/RIBs/ReportFlow.swift` and `Root/RIBs/FollowFlow.swift` sentence-case titles are outside ownership — see Needs a change elsewhere. |
| 15 | fixed (within owned folders) | Localized every bare-literal site in scope, including notification row titles, "PR:"/"kg lifted", macro labels, "You" fallbacks, and hand-written plurals (now `inflect: true`). `Managers/Invites/CoreInteractor+Invites.swift` is outside ownership — see Needs a change elsewhere. |
| 16 | fixed | "Decline"/"Add to Library" on SharedItemView; "Report…"/"Report Workout…"/"Share with Friends…" carry an ellipsis; "This Week" title-cased; FollowersList empty state reads "No Followers Yet". |
| 17 | not applicable | `Core/Profile/ProfilePresenter.swift` is outside this assignment's owned folders. |

**Smaller items:** nutrition card no longer fakes a target (shows totals/empty bars instead of
invented 2000 kcal etc.) — fixed. `SharedItemView`'s exercise-image fallback to
`Constants.randomImage` removed (uses the design system's own `nil`-image placeholder) — fixed.
Comment delete alert now has an explicit Cancel — fixed. A failed like now plays an error haptic
(WorkoutSessionRow and Comments) — fixed. Copy Link now also raises a toast, not haptic alone —
fixed. Seventy lines of commented-out streak code in `DashboardPresenter` deleted — fixed. Kept as
is: the feed/share volume being always kg (a unit-preference wiring change, larger than a smaller
item); the bare `ProgressView` loading states that `CONTRACT.md` asks to redact (a contract item,
left for a follow-up pass); the `.provisional`/`.ephemeral` "Notifications Disabled" wording (the
review itself notes it is latent, since the app requests neither today).

## Findings

### 1. The app schedules reminders nobody asked for, and nothing in the app turns them off
Severity: hurts usability (App Review exposure)
Where: `Managers/Push/PushManager.swift:76-111` (titles at `:87`, `:94`, `:101`), `:132-157`
(meal reminders, table at `:137-139`), `:159` (`cancelMealReminderNotifications` has no caller);
`Core/AppView/AppView.swift:35`, `Core/AppView/AppPresenter.swift:47-48`;
`Core/Nutrition/NutritionPresenter.swift:179-190`; the settings that do not cover them,
`Core/Notifications/NotificationsView.swift:74-89`, `:258-272`
Guideline: "Don't use notifications to send marketing or promotional content unless people
explicitly agree to receive such information." and "Make sure people can manage their
notification settings within your app." —
https://developer.apple.com/design/human-interface-guidelines/managing-notifications
Also "Avoid sending a notification that tells people to perform specific tasks within your app."
and "Avoid sending multiple notifications for the same thing" —
https://developer.apple.com/design/human-interface-guidelines/notifications
What happens: every launch schedules three come-back notifications for one, three and five days
out ("Keep up the momentum!", "Stay Consistent", "Don't Lose Your Streak!"), and the first visit to
the Nutrition tab schedules three repeating daily meal reminders. Neither reads any setting. The
"Streak reminder" switch only governs the server push, so someone who turns it off still gets the
local "Don't Lose Your Streak!", and someone with it on gets both. The streak one fires whether or
not there is a streak, and "Time for Breakfast" fires whether or not breakfast is logged. Since
the permission is now asked by the rest timer, a person who allowed notifications to hear their
rest end starts receiving all six.
Fix: delete `schedulePushNotificationsForNextWeek` and its call; the server's streak reminder
already covers the one case that carries information. Make meal reminders opt-in: a "Meal
reminders" switch, default off, beside the others in the notification settings, which calls
`scheduleMealReminderNotifications` or `cancelMealReminderNotifications`. Drop the
`hasMealRemindersScheduled` auto-schedule, and cancel the reminders already scheduled on devices
that never chose them.
Size: M
Decision needed: yes — are come-back notifications wanted at all, and should people who already
have meal reminders keep them?

### 2. Reporting is two alerts: four reasons with no Cancel, then a text field
Severity: hurts usability
Where: `Root/RIBs/ReportFlow.swift:56-73`, `:116-135`; reached from
`Core/Dashboard/WorkoutSessionRow/WorkoutSessionRowView.swift:204-208`,
`Core/Dashboard/WorkoutSessionRow/Comments/CommentsView.swift:54-59`,
`Core/Dashboard/SocialProfile/SocialProfileView.swift:52-54`
Guideline: "alerts display a title, optional informative text, and up to three buttons", "Use an
action sheet — not an alert — to offer choices related to an intentional action" and "include a
text field only if you need people's input to resolve the situation" —
https://developer.apple.com/design/human-interface-guidelines/alerts
What happens: choosing Report raises an alert whose only buttons are Spam, Harassment,
Inappropriate and Other. The router passes them straight to SwiftUI's `.alert`, which adds no
Cancel when buttons are supplied, so the only way out is to pick a reason and cancel the next
alert. That next alert takes a note of up to 500 characters in a one-line field, and a validation
failure dismisses it and raises it again.
Fix: one small sheet (`.sheetConfig(config: .half)`): a reason picker, a multi-line
`TextField(axis: .vertical)` with the validation message under it as an `InlineMessage`, close and
confirm in the toolbar. `ReportFlow.validationMessage` is already pure and tested, so only the
presentation changes. The smallest stopgap is `showConfirmationDialog` for the reasons, which
gets a Cancel for free.
Size: M
Decision needed: no

### 3. The Dashboard's carousel cards have a fixed 200 pt body
Severity: hurts usability (at large text sizes)
Where: `Components/Views/DashboardCard.swift:22`, `:39`; `Core/Dashboard/DashboardView.swift:25`,
`:88-90`, `:121`; `Core/Dashboard/Components/NutritionCard.swift:22-64`;
`Components/Views/ActivityRingView.swift:59-71`;
`Core/Training/Components/WorkoutStreakCard/WorkoutStreakCard.swift:21-26`
Guideline: "Be prepared for text-size changes… Apps that don't respond to this setting can be
difficult or impossible to use for people who rely on this feature." —
https://developer.apple.com/design/human-interface-guidelines/layout
"Support larger text sizes… Ideally, give people the option to enlarge text by at least 200
percent" — https://developer.apple.com/design/human-interface-guidelines/accessibility
What happens: only the card's title height scales (`carouselTitleHeight`). The body is
`frame(height: 200)` with 16 pt of padding each side, leaving 168 pt. The nutrition card puts an
80 pt ring, three labelled bars, a caption row and a glass button in that, which is already about
full at the default size; the streak card holds a `Font.display` number, the week row, a divider
and two stats. As text grows the content has nowhere to go, so the last element, "Log a Meal", is
the one that gets squeezed or clipped. The ring's calorie figure is `.font(.label)` inside a fixed
80 pt circle with no scale factor.
Fix: scale the body the same way the title already is, and let the ring scale with it.
```swift
// DashboardView
@ScaledMetric(relativeTo: .body) private var carouselContentHeight = DashboardCard<EmptyView>.contentHeight
```
Pass it to `DashboardCard` instead of the static, and size `ActivityRingView` from a
`@ScaledMetric` as `ChallengeRing` does. At accessibility sizes stack the ring above the bars with
the `AdaptiveStack` the feed row uses.
Size: M
Decision needed: no

### 4. Controls with a hit region well under 44 pt
Severity: hurts usability
Where (17 sites, the pattern is the same in each):
- `Core/Dashboard/WorkoutSessionRow/WorkoutSessionRowView.swift:162-213` — like, comment, share
  and More. `frame(maxWidth: .infinity)` is on the button, not its label, and the style is
  `.plain`, so the region is the glyph at `.subheadline` size
- `Core/Dashboard/WorkoutSessionRow/Comments/CommentsView.swift:102-121` (heart, 32 pt wide),
  `:134-141` (cancel reply), `:178-184` (send)
- `Core/Dashboard/CircleActivityStripView.swift:97-108`, `:154-160` — Nudge and Set goal at
  `.controlSize(.mini)`
- `Core/Dashboard/CircleGoals/CircleWeeklySummaryCard.swift:25-29`,
  `Core/Dashboard/InviteFriendCard.swift:36-40`, `Core/Dashboard/UsernameBannerView.swift:37-43`
  — plain, icon-only close buttons
- `Core/Dashboard/WeeklyReview/WeeklyReviewView.swift:94-107` — previous and next week chevrons
- `Components/Views/SectionHeaderView.swift:30-34` — "Find People", caption-size plain text
- `Core/Dashboard/SocialProfile/SocialProfileView.swift:96-100`, `:123-132`, `:244-249`
- `Core/Challenges/ChallengesDashboardSection.swift:24-28` — "New"
- `Components/Views/User/UserRowView.swift:96-110` and
  `Core/Notifications/NotificationsView.swift:122` — Follow, Accept and Decline at
  `.controlSize(.small)`
Guideline: "As a general rule, a button needs a hit region of at least 44x44 pt" —
https://developer.apple.com/design/human-interface-guidelines/buttons
"For elements without a bezel, about 24 points of padding works well around the element's visible
edges." — https://developer.apple.com/design/human-interface-guidelines/accessibility
What happens: the feed's four actions are each a roughly 20 pt glyph in a quarter-width column
where the whole column looks tappable. Like and comment are the most used controls on the screen
and the easiest to miss. The `.small` glass buttons are about the HIG's 28 pt minimum rather than
under it; they are listed because Accept and Decline sit 12 pt apart.
Fix: `Chip.swift:64` already has the answer as `chipTapTarget()`. Give it a general name and apply
it to the label, not the button:
```swift
Button { presenter.onLikeButtonPressed() } label: {
    Label("\(presenter.likeCount)", systemImage: …)
        .frame(maxWidth: .infinity, minHeight: ControlSize.row)
        .contentShape(.rect)
}
```
Size: M
Decision needed: no

### 5. A failed load is shown as "nothing here yet"
Severity: hurts usability
Where: `Core/Dashboard/WorkoutSessionRow/Comments/CommentsPresenter.swift:52`,
`CommentsView.swift:25-31` (the file's own "Load Failed" preview at `:243-254` says so);
`Core/Dashboard/SocialProfile/SocialProfilePresenter.swift:130-150`,
`SocialProfileView.swift:205-211`; `Core/Notifications/NotificationsPresenter.swift:104-112`,
`NotificationsView.swift:167-174`
Guideline: "Show people when a command can't be carried out and help them understand why." —
https://developer.apple.com/design/human-interface-guidelines/feedback
"Write clear error messages… be clear about what someone can do to fix it." —
https://developer.apple.com/design/human-interface-guidelines/writing
What happens: offline or on a server error, a thread with forty comments reads "No Comments Yet.
Start the conversation.", a profile reads "No Workouts Yet" with 0 followers, and the inbox reads
"You don't have any notifications yet." Each states something false and offers no retry.
Fix: keep the error instead of discarding it with `try?`, and show
`ContentUnavailableView("Unable to Load Comments", systemImage: Symbol.warning)` with a Try Again
button that calls the loader. One `loadFailed` flag per presenter.
Size: M
Decision needed: no

### 6. Reply, Report, Delete and Remove exist only as swipe actions
Severity: hurts usability
Where: `Core/Dashboard/WorkoutSessionRow/Comments/CommentsView.swift:37-61`;
`Core/Dashboard/SocialProfile/FollowersList/FollowersListView.swift:40-49`
Guideline: "Offer alternatives to gestures. Make sure your UI's core functionality is accessible
through more than one type of physical interaction… offer onscreen ways to achieve the same
outcome." — https://developer.apple.com/design/human-interface-guidelines/accessibility
What happens: nothing on a comment row says it can be replied to, reported or deleted. Reply is
the thread's main action and Report is the safety control App Review looks for on user-generated
content, and both are invisible until someone swipes. `CircleActivityStripView.swift:35-37`
already makes this argument for Nudge and chose a visible button.
Fix: a "Reply" text button under each comment, and the row's remaining actions in a
`.contextMenu` as well as the swipe (Report, or Delete with `role: .destructive` on the reader's
own). Same for Remove on the followers list. Keep the swipe actions as the shortcut.
Size: S
Decision needed: no

### 7. Tapping a notification stacks sheets on the Notifications sheet
Severity: hurts usability
Where: `Core/Notifications/NotificationsView.swift:239-243` (Notifications is a sheet);
`Core/Notifications/NotificationsPresenter.swift:224-236`;
`Core/Training/Subviews/WorkoutSessionDetailView/WorkoutSessionDetailView.swift:240-258`;
`Core/Sharing/SharedItem/SharedItemView.swift:90-94`;
`Core/Dashboard/DashboardPresenter.swift:135-141`
Guideline: "Display only one sheet at a time from the main interface… If closing a sheet takes
people back to another sheet, they can lose track of where they are in your app." —
https://developer.apple.com/design/human-interface-guidelines/sheets
"Take care to avoid creating a modal experience that feels like an app within your app." —
https://developer.apple.com/design/human-interface-guidelines/modality
What happens: a like opens the session as a second sheet. A comment or mention opens the session
as a second sheet and the comments as a third. A share opens a second sheet. A follow pushes a
profile inside the sheet, and from there the followers list, more profiles and their sessions are
all reachable, so a whole browsing session can happen inside one modal.
Fix: push Notifications from the Dashboard instead of presenting it, so a row's destination is the
only sheet. If it stays a sheet, push the session and the shared item onto its own stack, and open
comments by pushing from the session detail rather than as a sheet over it.
Size: M
Decision needed: yes — should Notifications be a pushed screen rather than a sheet?

### 8. Up to ten settings rows sit above the notifications themselves
Severity: hurts usability
Where: `Core/Notifications/NotificationsView.swift:49-72`, `:74-89`, `:258-272`
Guideline: "Pay attention to the order of elements on a screen, and put the most important
information first." — https://developer.apple.com/design/human-interface-guidelines/writing
"Put general, infrequently changed settings in your custom settings area." —
https://developer.apple.com/design/human-interface-guidelines/settings
What happens: with push allowed, the bell opens onto Likes, Comments, Mentions, New followers,
Nudges, Shares, Challenges, Streak reminder, its time picker and Weekly digest. On an iPhone the
first actual notification is below the fold every time, under switches most people set once.
Before permission is decided the top of the screen is a large prompt followed directly by a second
empty state.
Fix: move the switches to a "Notification Settings" screen, pushed from a toolbar button here and
from Profile's settings. Leave the inbox, follow requests and, only while undecided or denied, the
permission row.
Size: M
Decision needed: yes — where does the settings screen live, here or under Profile?

### 9. The Notifications screen blanks to a spinner on every load, including pull to refresh
Severity: polish
Where: `Core/Notifications/NotificationsView.swift:16-22`, `:45`;
`Core/Notifications/NotificationsPresenter.swift:31`, `:104-119`, `:133`
Guideline: "Show something as soon as possible. If you make people wait for loading to complete
before displaying anything, they can interpret the lack of content as a problem with your app" —
https://developer.apple.com/design/human-interface-guidelines/loading
What happens: `isLoading` starts true and is set again by every `loadNotifications()`. Follow
requests and the cached notifications are already in memory but wait behind the network call. On
pull to refresh the list being pulled is replaced by a bare `ProgressView` and then rebuilt, which
loses the scroll position. That the list is torn down mid-gesture is my reading of the code, not
observed.
Fix: show the list at once from what is held. Drop `isLoading` from `onPullToRefresh` (the refresh
control is the indicator) and use it only when the list is empty on first load.
Size: S
Decision needed: no

### 10. Every push shows a banner and plays a sound while the app is open
Severity: polish
Where: `Root/AppDelegate.swift:134-140`
Guideline: "Handle notifications gracefully when your app is in the foreground… present the
information in a way that's discoverable but not distracting or invasive, such as incrementing a
badge or subtly inserting new data into the current view." —
https://developer.apple.com/design/human-interface-guidelines/notifications
What happens: `willPresent` always returns `[.banner, .sound, .badge]`. Someone reading a comment
thread gets a banner and a sound for the reply that is about to appear in front of them, and the
bell's badge already counts it.
Fix: return `[.list, .badge]` for the social types, which `userInfo["type"]` identifies, and keep
the banner for the rest timer, where the alert is the point.
Size: S
Decision needed: no

### 11. No notification sets an interruption level, and the badge is always 1
Severity: polish
Where: `functions/lib.js:108`, `:304`, `:335`; `Managers/Push/PushManager.swift:113-122`,
`:132-157`, `:69-74`
Guideline: "You need to specify a system-defined interruption level for each noncommunication
notification you send." and "Build trust by accurately representing the urgency of each
notification." —
https://developer.apple.com/design/human-interface-guidelines/managing-notifications
"Use a badge only to show people how many unread notifications they have." and "Keep badges up to
date." — https://developer.apple.com/design/human-interface-guidelines/notifications
What happens: everything goes out at the default, Active, so a like interrupts exactly as a
follow request does. Social pushes hard-code `badge: 1`, so five unread notifications show 1 on
the icon, and it clears only when the Notifications screen is opened, not when the push itself is
tapped.
Fix: `"interruption-level": "passive"` in the `aps` payload for likes and the weekly digest, and
`.passive` on meal reminders. Leave comments, mentions, follow requests, nudges and shares Active.
Send the recipient's unread count as the badge, since the function already has their
notifications collection.
Size: M
Decision needed: yes — which types are passive, and is "Rest Complete" worth the Time Sensitive
capability? It is the one notification about something happening now.

### 12. Notification copy: capitalization, punctuation, emoji, generic titles, English only
Severity: polish
Where: `functions/lib.js:62-102`, `:303`, `:332-333`; `Managers/Push/PushManager.swift:87-103`,
`:137-139`
Guideline: "If you can only provide a generic title for a noncommunication notification — like New
Document — it can be better to let the system display your app name instead. Use title-style
capitalization and no ending punctuation." and "Use complete sentences, sentence case, and proper
punctuation" for the body —
https://developer.apple.com/design/human-interface-guidelines/notifications
What happens: titles are sentence case ("New like", "Streak at risk", "Your week", "Request
accepted") or end in punctuation ("Keep up the momentum!"). Bodies have no full stop ("Alice liked
your workout"). "New like", "Mention" and "Nudge" are the generic kind the page describes. Three
titles carry emoji, which the page does not rule on; that one is my judgment. All of it is English
whatever the device language, in an app whose catalog is complete in Spanish.
Fix: use the actor as the title and the event as the body ("Alice" / "Liked your workout."), or
drop the title and let the system show the app name. Title case what stays ("Streak at Risk").
End bodies with a full stop. Send `title-loc-key` and `loc-key` with arguments so the device
localizes, and take local strings through `String(localized:)`.
Size: M
Decision needed: no

### 13. Four ways to share a workout, and the Share button is the one without the link
Severity: polish
Where: `Core/Dashboard/WorkoutSessionRow/WorkoutSessionRowView.swift:178-203`;
`WorkoutSessionRowPresenter.swift:129-144`, `:177-189`, `:198-202`;
`Core/Dashboard/ShareCard/ShareCardRenderer.swift:43-66`;
`Core/Dashboard/WeeklyReview/WeeklyReviewPresenter.swift:72-81`;
`Managers/Invites/CoreInteractor+Invites.swift:87-94`
Guideline: "Use the Share button to display an activity view… Avoid confusing people by providing
an alternative way to do the same thing." and "Avoid creating duplicate versions of common actions
that are already available in the activity view." —
https://developer.apple.com/design/human-interface-guidelines/activity-views
What happens: the Share button sends a line of text ("Push Day · 6 exercises · 18 sets · 5400 kg
lifted") with no link, although the session has a public page. The link is only in More > Copy
Link, the image only in More > Share Image > a format, and sending to a follower is a third item.
Copy is already a share sheet action. The image path wraps `UIActivityViewController` in a SwiftUI
sheet with detents, so on iPad it is a sheet within a sheet rather than a popover from the button;
that part is my judgment and needs a run on iPad.
Fix: `ShareLink(item: presenter.webLink, message: Text(presenter.shareSummary))` when there is a
link, the summary alone when there is not. Copy Link then comes from the share sheet and leaves
the menu. For the image, a `Transferable` whose `DataRepresentation` renders the card on export
lets `ShareLink` replace `ShareSheet`, so the comment at `ShareCardRenderer.swift:41-42` no longer
holds. Keep "Share with Friends" as the app's own item.
Size: M
Decision needed: yes — is the link or the image the primary thing to share?

### 14. Alerts: a title of "Error", alerts that only inform, a choice inside an alert, mixed capitalization
Severity: polish
Where:
- "Error": `Root/RIBs/GlobalRouter.swift:40`, used at
  `Core/Notifications/NotificationsPresenter.swift:82`, `:125`, `:138`, `:323`, `:387`
- information only: `Root/RIBs/ReportFlow.swift:100-103` ("Report Sent"),
  `Core/Dashboard/WorkoutSessionRow/WorkoutSessionRowPresenter.swift:227-232` ("Saved to your
  workouts")
- choice: `Core/Dashboard/DashboardPresenter.swift:368-396`
- capitalization, 24 "Unable to…" titles in this area: title case at
  `CommentsPresenter.swift:139`, `:275`, `WorkoutSessionRowPresenter.swift:186`, `:210`,
  `NotificationsPresenter.swift:155`, `ReportFlow.swift:105`; sentence case at
  `Root/RIBs/FollowFlow.swift:83-85`, `SocialProfilePresenter.swift:176`, `:226`, `:238`,
  `ChallengeDetailPresenter.swift:115`, `CreateChallengePresenter.swift:97`,
  `WeeklyGoalPresenter.swift:41`; and "Couldn't accept invite" at
  `Managers/Invites/CoreInteractor+Invites.swift:73`
Guideline: "Avoid writing a title that doesn't convey useful information — like 'Error'", "Avoid
using an alert merely to provide information", "If the title is a sentence fragment, use
title-style capitalization", and for button titles "use title-style capitalization" —
https://developer.apple.com/design/human-interface-guidelines/alerts
"Use an action sheet — not an alert — to offer choices related to an intentional action." —
https://developer.apple.com/design/human-interface-guidelines/action-sheets
What happens: a failed notification switch says "Error" over a raw `localizedDescription`.
Reporting and saving a template each end in an alert that must be dismissed to hear that it
worked. Tapping Log a Meal with a draft open raises "Unable to add new meal / You already have an
draft meal." with "Continue editing", "Delete drafted meal" and Cancel: a choice presented as a
failure, with a typo and sentence-case buttons.
Fix: give `showAlert(error:)` a title parameter so each caller says what failed ("Unable to Save
Setting"). Use the existing `showAppToast` for "Report sent" and "Saved to your workouts", keeping
Open as the toast's action if it supports one. Make the draft prompt
`showConfirmationDialog(title: "You Have a Draft Meal")` with "Continue Editing" and "Delete
Draft". Settle on title case for fragment titles and apply it to the sentence-case ones.
Size: M
Decision needed: no

### 15. User-facing strings that bypass the string catalog
Severity: polish
Where (15 of about 25 sites):
- `Core/Notifications/NotificationsView.swift:144-165` — all eight notification row titles
- `Root/RIBs/ReportFlow.swift:49-52`, `:102`, and the English `noun` interpolated at `:61-62`
- `Core/Challenges/CreateChallenge/CreateChallengePresenter.swift:42`, `:49`, `:50`
- `Core/Dashboard/SocialProfile/SocialProfilePresenter.swift:163`, `:311-312`
- `Core/Dashboard/SocialProfile/FollowersList/FollowersListView.swift:7`
- `Core/Dashboard/Components/NutritionCard.swift:33-35` — "Protein", "Carbs", "Fat" passed as
  `String`
- `Core/Dashboard/WorkoutSessionRow/WorkoutSessionRowView.swift:97` ("PR: …"),
  `WorkoutSessionRowPresenter.swift:141` ("kg lifted")
- `Core/Dashboard/CircleGoals/CircleLeaderboardView.swift:46`,
  `Core/Challenges/ChallengeDetail/ChallengeDetailView.swift:78`,
  `Core/Challenges/ChallengesDashboardSection.swift:78` — "You"
- `Core/Dashboard/WeeklyReview/WeeklyReview.swift:175`, `:193`, `:200`
- `Core/Sharing/SharedItem/SharedItemPresenter.swift:85`
- `Managers/Invites/CoreInteractor+Invites.swift:73-74`, `:92`
- `Core/Dashboard/WorkoutSessionRow/Comments/CommentsView.swift:86`
Guideline: "Choose simple, plain language and write with accessibility and localization in mind"
— https://developer.apple.com/design/human-interface-guidelines/writing
What happens: these are plain `String` values, so `Text` shows them verbatim. In Spanish the
notifications list, the report flow and the challenge form's validation stay English beside
translated neighbours. Several hand-write plurals ("session"/"sessions", "PR"/"PRs" at
`WeeklyReview.swift:157`, `:166`, `CircleWeek.swift:122`, `WeeklyGoalView.swift:13`), which
`CLAUDE.md` rules out.
Fix: `String(localized:)` with catalog plural variations. For reports, replace `noun` with a
localized title and sentence per `ReportContentType`, since a noun dropped into a sentence does
not survive Spanish gender or `.capitalized`.
Size: M
Decision needed: no

### 16. Labels that do not say what the control does
Severity: polish
Where: `Core/Sharing/SharedItem/SharedItemView.swift:62`, `:65`;
`Core/Dashboard/WorkoutSessionRow/WorkoutSessionRowView.swift:188`, `:205`;
`Core/Dashboard/SocialProfile/SocialProfileView.swift:52`;
`Core/Dashboard/CircleGoals/CircleLeaderboardView.swift:28`;
`Core/Dashboard/SocialProfile/FollowersList/FollowersListView.swift:21-25`
Guideline: "Ensure that each button clearly communicates its purpose" and "Using title-style
capitalization, consider starting the label with a verb" —
https://developer.apple.com/design/human-interface-guidelines/buttons
"Append an ellipsis to a menu item's label when the action requires more information before it
can complete." — https://developer.apple.com/design/human-interface-guidelines/menus
What happens: on a shared workout "Dismiss" sits under the primary button and a close button sits
in the toolbar. Dismiss declines the share for good; close only closes. "Report" and "Share
Workout with Friends" both open a further step and carry no ellipsis. "This week" is sentence
case beside "Challenges" and "Workout Feed". The empty followers list says "People will show up
here once there are some."
Fix: "Decline" and "Add to Library"; "Report…", "Report Workout…", "Share with Friends…"; "This
Week"; and an empty state per list, such as "No Followers Yet".
Size: S
Decision needed: no

### 17. Profile's "Rate us" asks "enjoying the app?" before the system prompt
Severity: polish
Where: `Core/Profile/ProfilePresenter.swift:146-163`, `Root/RIBs/Core/CoreRouter.swift:35-39`
(outside this area's folders; included because the assignment names the ratings prompt)
Guideline: "Prefer the system-provided prompt." —
https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews
What happens: the row opens a custom Yes/No modal and requests the review only on Yes. The system
also limits the prompt to three showings a year, so a Yes can do nothing at all; that last point
is from the same page's description of the limit, the consequence is my judgment.
Fix: make the row open the App Store's write-review page
(`https://apps.apple.com/app/id<ID>?action=write-review`) and delete the modal. Keep
`requestRatingsReview()` for the automatic prompt, which is timed well (see Done well).
Size: S
Decision needed: no

## Smaller items

- `Core/Dashboard/DashboardView.swift:128-139`: with no nutrition target the card draws progress
  against invented ones (2000 kcal, 150 g, 250 g, 70 g) as if they were the user's. Show the
  totals without a target, or a "Set a Target" action. My judgment.
- `Core/Dashboard/WorkoutSessionRow/WorkoutSessionRowPresenter.swift:70`, `:89`, `:141`: the feed
  and the share text are always kilograms, whatever the reader's unit. My judgment; README
  follow-up decision 3 points the same way for Goal Progress.
- `Core/Sharing/SharedItem/SharedItemView.swift:34`: an exercise with no image gets
  `Constants.randomImage`. `CommentsView.swift:81-82` records removing the same fallback as a bug.
  `SocialProfileView.swift:259-263` falls back to the splash image where `UserAvatarView` exists.
- `Core/Dashboard/WorkoutSessionRow/Comments/CommentsPresenter.swift:255-263`: the delete alert
  supplies only a destructive button. Whether SwiftUI adds Cancel here was not verified. Every
  other confirmation in the area passes one explicitly; this should too. "If there's a destructive
  action, include a Cancel button" (alerts page).
- `WorkoutSessionRowPresenter.swift:115-118`, `CommentsPresenter.swift:241-243`: a like that fails
  flips back with no haptic and no message. `:198-202`: Copy Link confirms with a haptic only,
  which is nothing on iPad or with haptics off. "Make sure all feedback is accessible" (feedback
  page).
- `Core/Dashboard/DashboardView.swift:175-180`, `SocialProfileView.swift:200-204`,
  `CommentsView.swift:20-24`: list content loads behind a bare `ProgressView`. `CONTRACT.md` asks
  for `.redacted(reason: .placeholder)` rows here. A contract item rather than a HIG one.
- `Core/Notifications/NotificationsView.swift:61`: `.provisional` and `.ephemeral` are shown as
  "Notifications Disabled". The app requests neither today, so this is latent.
- `Core/Dashboard/DashboardPresenter.swift:154-224`: seventy lines of commented-out streak code.

## Contract conflicts

None found. The places where this area follows the contract and a reader might expect otherwise
(`role: .confirm` drawing a checkmark for Send and Create, `role: .close` instead of a Cancel
title, the monochrome accent) are not contradicted by any page read.

## Done well — keep

- **Blocking and removing.** Block confirms first and says exactly what it does ("hidden from your
  feed, comments, search and notifications, and you will stop following them"). Remove Follower
  says the person will not be told. Blocked authors are filtered from the feed, the strip and
  comment threads, with their replies.
- **Privacy by default.** The session note is shown to its author only. The share card uses a first
  name. The web link is absent for a private author. A date of birth was removed from the profile.
- **The automatic review prompt.** It uses the system prompt, after the third real workout has
  saved, which is a natural stopping point, with a 120-day cooldown and never under UI tests
  (`Managers/Training/ReviewPrompt.swift`).
- **Permission in context.** Notifications are requested from the Notifications screen with one
  button, the denied state links straight to Settings, and the in-app list works without push.
- **Per-type switches** for every server push, written as they flip.
- **Optimistic writes that undo properly.** A comment that fails to post comes back out of the list
  and its text goes back in the field.
- **VoiceOver.** The feed card is one stop with separate stops for its controls; like buttons carry
  a label and a count; rings, leaderboard rows and the strip's faces read as sentences; unread is
  announced; selected rows carry `.isSelected`.
- **Dynamic Type in rows.** `AdaptiveStack`, `ViewThatFits` and `FlowLayout` are used where a row
  would otherwise truncate, and `ChallengeRing` scales with the text.
- **Not colour alone.** Trained-today has a checkmark, finished has a seal, the leader has a crown,
  the liked thumb is filled.
- **No Activity rings.** The progress rings are single rings in the app's own colours with the
  value inside, not the Move, Exercise and Stand element, so the `healthkit` page's ring rules are
  not engaged. `ActivityRingView` is only a name; renaming it `ProgressRing` would stop the next
  reader checking.
- **Nudge** is a visible button, once per person per day, greyed at once.
- **Empty states** use `ContentUnavailableView` with an action where one exists (Find People, with
  suggested people under it).
