# HIG decisions needed (2026-09-28)

Findings the reviewers marked as needing a product decision. Each line is the question; the finding has the detail.

## Decided with the owner, 2026-09-29

Every question below was put to the owner and answered. "Build now" says whether it is to be
built straight away or is recorded for later. Where an answer was not given, the default taken
is stated. Figures that are health limits are on `docs/release-checklist.md` for someone
qualified to confirm.

| # | Decision | Outcome | Build now? |
|---|---|---|---|
| 1 | Non-subscribers trapped at the paywall | **Exits only.** Add Sign Out and an Account link (reaching Delete Account) to the paywall and to "Why Subscribe?", and state that a subscription is required. App stays premium-only. | Yes |
| 1a | Free trial | **Planned, not now.** An app-managed trial: access for a set period with no payment sign-up, then a prompt to subscribe. Not an App Store introductory offer. | No |
| 2 | Legal documents | Documents do not exist yet; to be hosted on the owner's website. **Placeholders stay**, each marked `// TODO:` with a scoped `swiftlint:disable:next todo`, and listed in a new `docs/release-checklist.md`. Link the Health Disclaimer and Consumer Health Privacy Notice beside their consent toggles now. | Yes |
| 2a | Health consent steps | **Drop the confirmation alert**: two toggles and Continue (3 presses, was 4). A single "Agree and Continue" waits on legal advice. | Yes |
| 3 | Weekly rate limit | **Cap at 1% of body weight a week, plus a warning** near the top of each person's range. | Yes |
| 3a | Target weight floor | **From height**: the wheel stops at BMI 18.5 and says why. | Yes |
| 3b | 800 kcal floor | **Removed from onboarding**, kept in settings. | Yes |
| 3c | Health limits | The 1%, BMI 18.5 and 800 kcal figures to be confirmed by someone qualified before release; on the release checklist. | Checklist |
| 4 | Rest-over channel | **The Live Activity alerts.** The notification is kept only for people with Live Activities off. The rest timer gets one owner so every start, adjust, skip, finish and discard moves or cancels the alert. | Yes |
| 4a | Rest sound on silent | **Respects the silent switch** and mixes with music. A system sound stands in until the owner supplies a file. | Yes |
| 4b | Rest-over text | **Says what is next**, e.g. "Next: Bench Press, 60 kg × 8". | Yes |
| 5a | Swapping an exercise | **Logged sets move to the new exercise** when both are measured the same way. When they are not, ask first ("Swap and Discard Sets" / Cancel). | Yes |
| 5b | Pause | **Add Pause and Resume** to the tracker menu; clock, Apple Health and Live Activity follow. | Yes |
| 5c | Finishing | **Show the session detail screen**, play the success haptic, and ask before saving a workout with no sets. | Yes |
| 5d | Done on the set keyboard | **Logs the set**, no alert. | Yes |
| 6 | Sheets or pushes | **Browsing pushes.** Profile is a full-screen cover (it has no clear beginning and end, and keeps its zoom transition, which a push would lose); Notifications stays a sheet; everything inside both pushes; creating and editing stay sheets. One tab at a time, Analytics first. Remove each screen's own Close button where it becomes a push. | Yes |
| 7a | Come-back reminders | TO CONFIRM: owner wrote "1A" (remove) and "on by default, can opt out in settings". | Pending |
| 7b | Meal reminders | **Off by default.** An in-app prompt offers them the first time Nutrition is opened; a switch in Notification Settings. Existing scheduled reminders are cancelled unless turned on. | Yes |
| 7c | Streak reminder | **Offered once the person reaches a 3-day streak**; a switch in Notification Settings. | Yes |
| 7d | Weekly digest | Stays on by default (not changed by the owner's answer). | TO CONFIRM |
| 7e | Route from Profile | **Add** a Notification Settings row in Profile's settings. | Yes |
| 8a | Gender question | **Ask for sex, and say why.** Title "Sex for Calorie Estimate", subtitle "Used only to estimate the calories you burn." Add "Prefer not to say", using the midpoint coefficient; the screen says the estimate is less accurate. Midpoint value on the release checklist for confirmation. | Yes |
| 8b | Explaining each question | **One sentence per step**: what the answer feeds, and that it can be changed in Profile. Drafts to the owner for approval. | Yes |
| 8c | Cardio fitness step | **Remove** (owner leaning that way; it was meant to inform expenditure but does not). Saved values stay on existing profiles. | Yes, unless the owner objects |
| 9a | After adding a food | **Return to the food list**, with a checkmark and count on the row and "N on plate" in the toolbar. Success haptic on every add; button renamed "Add". | Yes |
| 9b | AI disclosure | **Recommended wording**, adjusted to what the backend does (verified in `functions/index.js`): the photo and text are not stored by our functions; they are sent to Google's Vertex AI; recognized foods are saved to the person's library. Section titled "AI Estimate" with "Estimates can be wrong. Check amounts before logging." A result opens the amount screen prefilled. | Yes |
| 9c | Food Packaging step | **Hide the step and the "Share New Foods Publicly" setting.** Leave a `// TODO:` (with the lint exemption) for the public database contribution, and list it in the release checklist as not shipping. | Yes |
| 10a | Delete-account confirmation | A confirmation screen replaces the alert: what is deleted, that sign-in will be asked again, that Apple keeps billing the subscription (with Manage Subscription), progress while it runs, and "Account deleted" at the end. Remaining server data: **"within 30 days"**. | Yes |
| 10b | Product name | **"Compound"**, one name everywhere. No "Try… Today!" and no mention of a trial until the trial exists. After the future trial lapses, only paying users can use the app. | Yes |
| 10c | Rows for features that do not exist | Each marked `// TODO:` (with the lint exemption) so it can be filled in later. TO CONFIRM whether the rows stay visible; default taken: hidden from the UI, code and TODO kept. The Siri row links to the four shortcuts that do ship. | Yes |
| 10d | Rating prompt | **Apple's prompt only**, no custom card, requested after a successful moment: completing a full week of training or of food logging. | Yes |
| 11a | Editing a finished workout | **Now:** the row becomes "Edit Notes" and Save moves to the toolbar. **After the navigation work:** real editing of sets and exercises. | Yes, in two steps |
| 11b | Logging weight | **A second wheel for tenths**, for weight and body measurements. | Yes |
| 11c | Untracked nutrient cards | **Hidden.** The grid shows only nutrients the app tracks. | Yes |
| 11d | Diet and Strava in onboarding | **Strava moves out**: offered from settings and after the first finished workout. Diet setup stays. | Yes |
| 11e | Apple Health in onboarding | **"Fill from Apple Health" button** on the date of birth, sex, height and weight steps, each asking for that item only. | Yes |
| 7d | Weekly digest | Stays on by default, with its switch (recommended; owner said "go recommended for all"). | Yes |
| 10c | Unfinished rows | Hidden from the UI, code and TODO kept (recommended default). | Yes |
| 7a | Come-back reminders | **Kept, on by default, with a switch** in Notification Settings to turn them off (the owner's own wording; "1A" read as a slip). Noted: Apple's guidance prefers opt-in for promotional notifications. | Yes |
| 12a | Mac version | **To be fixed later.** Catalyst stays on. On the release checklist. Keyboard shortcuts added now for iPad (Command-1 to 4, Command-F), which the Mac will reuse. | Shortcuts yes; Mac later |
| 12b | App icon | No layered artwork yet. **Design task on the release checklist**: rebuild in Icon Composer from a background and a vector "C". | Checklist |
| 12c | Live Activity height | **Minimum height, not fixed**; grows only at larger text sizes. | Yes |
| 12d | Live Activity setting | **Add "Show on Lock Screen"** to Workout Settings, on by default. | Yes |
| 12e | Interruption levels | Likes, weekly digest and meal reminders **passive**; comments, mentions, follow requests, nudges and shares **active**; **Rest complete is Time Sensitive**. Badge shows the real unread count. Needs the Time Sensitive Notifications capability on the app ID. | Yes |
| 12f | Sharing a workout | **The Share button sends the link**, with the summary as its message. Copy Link leaves the menu. The image stays under More. | Yes |
| 13a | "Over goal" on the calendar | **A dashed ring** for over-goal days, solid for goal met. | Yes |
| 13b | Set table at large text | **A stacked layout at accessibility sizes**; normal sizes unchanged. | Yes |
| 13c | Bar above the tab bar | **Only the workout shows** when a workout and a draft meal are both open. | Yes |
| 13d | The + button on Training | **A menu** with New Program, New Workout, New Exercise. The Add Training sheet module is removed. | Yes |
| 13e | Muscle picker | Artwork is planned: **keep the grid**, mark the placeholder with a `// TODO:`, and **show Primary and Secondary clearly** on each tile, with a line explaining the taps. | Yes |
| 13f | Disabled rows in Notification Settings | **Left as they are.** | No change |
| 13g | Recipe title | **Match the other detail screens**: present the title the way Food detail, Workout template detail and the other detail views do. | Yes |

### Raised while building, and decided

| # | Decision | Outcome | Build now? |
|---|---|---|---|
| W1 | Rest-over alert on a locked phone | **Keep the app running during workouts** (workout background mode) so the Live Activity can alert on a locked phone. The 2-second notification fallback stays for people without Apple Health access. | Yes |
| W2 | Rest over with "Play Sound" off | **A silent notification**: a banner with no sound. | Yes |
| W3 | Paused time | **The saved duration excludes paused time.** Rest-over distance uses the person's unit. | Yes |
| O1 | Daily activity | **Add daily activity to Profile**, so it can be changed after onboarding. | Yes |
| O2 | Rate bands | Warning from 80% of the person's maximum, "Conservative" at 50% or less: accepted for now; on the release checklist. | Built |
| O3 | Apple Health sex "other" | Treated as nothing found; the choice is left blank. | Built |

### Decided earlier the same day

| Decision | Outcome |
|---|---|
| Tap targets on glass buttons | **Keep the system's size.** A glass `Button` only responds to taps on its visible glass, so its hit area cannot be widened without making the control bigger, which broke the layouts. Do not re-raise as a finding. |
| Where notification settings live | **Their own screen**, pushed from a gear button on Notifications (built). |
| Branching | `main` releases, `development` integrates. |

## The original questions

Kept for reference. All are answered in the table above.

### Raised by the notification settings work

- **Streak reminder and weekly digest default to on.** The HIG asks for explicit permission before promotional notifications. Are these promotional, and should they default to off? Today's default was kept.
- **Meal reminders and come-back notifications** have no switch at all. Add a "Meal reminders" switch, default off? Keep the come-back notifications?
- **A second route to Notification Settings** from Profile's settings. It is reached only from the gear on Notifications.
- **Disabled rows:** the switches dim but the row titles stay at full contrast. Dim the titles too?


### active-workout

- **1. Swapping an exercise throws away the sets already logged for it, without asking** (hurts usability (data loss))  
  keep the logged sets under the new exercise, or confirm and discard.
- **2. The rest-over notification is scheduled once and never moved or removed** (hurts usability)  
  Live Activity alert or notification as the one rest-over channel. Note: an uncommitted edit in `PushManager.schedulePushNotification` now asks for notification permission here, so the system alert appears when the first rest starts. The timing fits the privacy guidance; whatever replaces the scheduling must keep that request.
- **6. There is no pause, and the Live Activity has a paused state nothing can reach** (hurts usability)  
  does a strength workout pause?
- **7. Finishing a workout gives no summary and no confirmation, and an empty one is saved** (hurts usability)  
  summary screen, or session detail reused.
- **9. The Live Activity's rows are 38 pt high whatever the text size, and so are its buttons** (hurts usability — **by arithmetic, not run**)  
  whether the banner may grow, and whether resting keeps four controls.
- **10. Alerts are used for choices and for a routine step** (hurts usability)  
  what Done does on a ready set.
- **11. "Play Sound" plays nothing in the app, and will stop the user's music when it does** (hurts usability)  
  whether the rest sound should play with the phone on silent.
- **16. The Live Activity cannot be turned off from inside the app** (polish)  
  worth a setting, or leave it to the system toggle.

### analytics-charts

- **1. Weight and measurements can only be logged in whole units** (hurts usability)  
  wheel with a tenths column, or `NumberField`?
- **2. Every analytics screen is a sheet, and they stack three and four deep** (hurts usability)  
  move Analytics from sheets to push navigation?
- **8. Twenty-two of fifty-two nutrient cards are permanently "Not Tracked", at half opacity** (hurts usability)  
  hide untracked nutrients, or list them as text?

### dashboard-social

- **1. The app schedules reminders nobody asked for, and nothing in the app turns them off** (hurts usability (App Review exposure))  
  are come-back notifications wanted at all, and should people who already have meal reminders keep them?
- **7. Tapping a notification stacks sheets on the Notifications sheet** (hurts usability)  
  should Notifications be a pushed screen rather than a sheet?
- **8. Up to ten settings rows sit above the notifications themselves** (hurts usability)  
  where does the settings screen live, here or under Profile?
- **11. No notification sets an interruption level, and the badge is always 1** (polish)  
  which types are passive, and is "Rest Complete" worth the Time Sensitive capability? It is the one notification about something happening now.
- **13. Four ways to share a workout, and the Share button is the one without the link** (polish)  
  is the link or the image the primary thing to share?

### foundations

- **2. A calendar day reads as "M", "14" to VoiceOver, and goal met or missed is red against green** (hurts usability)  
  which mark means "over goal" on the ring
- **3. Text that matters is capped, shrunk or boxed in at large sizes** (hurts usability)  
  whether the set table gets a second, stacked layout or keeps its cap
- **12. The app icon is a flat image with its own rounded shape drawn in** (polish)  
  needs the source artwork

### nutrition

- **5. Adding a food gives no sign that it was added** (hurts usability)  
  after adding from an amount screen, return to the list or to the plate?
- **6. The AI features do not say they are AI, that data leaves the device, or that results are estimates** (hurts usability (trust), App Review exposure)  
  the disclosure wording, and whether photos and text are retained server side (the copy must match `docs/AppPrivacy.md`)
- **8. The Food Packaging step looks interactive where it is not, and drops the photos** (hurts usability)  
  is the public-database contribution shipping? If not, hide the toggle on Create Food and this whole step

### onboarding-data-steps

- **1. The goal steps accept and display unsafe values with no feedback** (hurts usability (health and safety))  
  what the maximum weekly rate and the lowest selectable target should be, and whether they depend on body weight and height.
- **2. People are asked to accept a privacy notice the screen neither shows nor links** (hurts usability (trust), App Review exposure)  
  the real document URLs, and whether legal needs the second confirmation.
- **3. Gender is required, offers two options, and gives no reason** (hurts usability (inclusion))  
  which options to offer and what coefficient the non-binary and decline-to-state options use.
- **4. No data-entry step says why it is asking or whether the answer is required** (hurts usability)  
  whether cardio fitness stays.
- **8. The calorie-floor step uses terms it does not define, and warns without saying of what** (hurts usability (health and safety))  
  whether the 800 kcal option is offered during onboarding at all.
- **11. The diet questions and the Strava step are setup that could wait** (hurts usability)  
  whether diet customization and Strava stay in onboarding.
- **13. Health data is typed in by hand, with no offer to read it from Apple Health** (hurts usability)  
  whether onboarding may ask for Health access at all, even on request.

### profile-settings-paywalls

- **2. Someone who will not subscribe cannot delete their account, sign out, or leave the paywall** (blocks people, App Review exposure)  
  premium-only is a stated product decision (`PremiumAccess.swift:29`). Is any free access or trial wanted, or only the exits?
- **4. Every legal link opens apple.com** (hurts usability (trust), blocks release)  
  where the documents will be hosted
- **5. The deletion alert says nothing about the subscription, the re-authentication or the timing** (hurts usability)  
  the time limit to state for server-side deletion
- **8. The custom paywall does not say what is being bought** (hurts usability, App Review exposure)  
  the product's name, and whether a trial exists
- **10. Settings is a modal that stacks three more modals** (hurts usability)  
  whether Profile itself should stay a sheet or become a pushed screen
- **16. Seven rows lead to a screen or alert that says the feature does not exist** (hurts usability)  
  whether the rows are kept as a visible roadmap

### shell-navigation

- **3. The rating prompt asks "Are you enjoying AIChat?"** (hurts usability)  
  system prompt, App Store link, or both
- **6. Sheets open sheets, three deep** (hurts usability)  
  Analytics details as pushes is a visible navigation change
- **13. The tab bar accessory ignores its inline placement and has two lines in a fixed height** (polish)  
  what to show when a workout and a draft meal are both open
- **15. No keyboard shortcuts or menu commands for iPad and Mac** (polish)  
  is the Mac version shipping, or should Catalyst be turned off

### training-library

- **1. Libraries open as sheets, and sheets then stack three and four deep** (hurts usability)  
  were the libraries made sheets on purpose (for example to keep the tab bar accessory out of the way)?
- **2. "Edit Workout" on a finished session opens no editor, and Save hides in the More menu** (hurts usability)  
  should a finished workout's sets be editable here?
- **15. A sheet to choose between three commands** (polish)  
  `showAddTrainingViewZoom` suggests other callers; confirm they can take a menu too.
- **16. Short option lists open a sheet, and the muscle picker is a grid of one image** (polish)  
  is muscle artwork planned?
