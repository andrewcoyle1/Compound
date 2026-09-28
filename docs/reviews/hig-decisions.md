# HIG decisions needed (2026-09-28)

Findings the reviewers marked as needing a product decision. Each line is the question; the finding has the detail.

## active-workout

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

## analytics-charts

- **1. Weight and measurements can only be logged in whole units** (hurts usability)  
  wheel with a tenths column, or `NumberField`?
- **2. Every analytics screen is a sheet, and they stack three and four deep** (hurts usability)  
  move Analytics from sheets to push navigation?
- **8. Twenty-two of fifty-two nutrient cards are permanently "Not Tracked", at half opacity** (hurts usability)  
  hide untracked nutrients, or list them as text?

## dashboard-social

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

## foundations

- **2. A calendar day reads as "M", "14" to VoiceOver, and goal met or missed is red against green** (hurts usability)  
  which mark means "over goal" on the ring
- **3. Text that matters is capped, shrunk or boxed in at large sizes** (hurts usability)  
  whether the set table gets a second, stacked layout or keeps its cap
- **12. The app icon is a flat image with its own rounded shape drawn in** (polish)  
  needs the source artwork

## nutrition

- **5. Adding a food gives no sign that it was added** (hurts usability)  
  after adding from an amount screen, return to the list or to the plate?
- **6. The AI features do not say they are AI, that data leaves the device, or that results are estimates** (hurts usability (trust), App Review exposure)  
  the disclosure wording, and whether photos and text are retained server side (the copy must match `docs/AppPrivacy.md`)
- **8. The Food Packaging step looks interactive where it is not, and drops the photos** (hurts usability)  
  is the public-database contribution shipping? If not, hide the toggle on Create Food and this whole step

## onboarding-data-steps

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

## profile-settings-paywalls

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

## shell-navigation

- **3. The rating prompt asks "Are you enjoying AIChat?"** (hurts usability)  
  system prompt, App Store link, or both
- **6. Sheets open sheets, three deep** (hurts usability)  
  Analytics details as pushes is a visible navigation change
- **13. The tab bar accessory ignores its inline placement and has two lines in a fixed height** (polish)  
  what to show when a workout and a draft meal are both open
- **15. No keyboard shortcuts or menu commands for iPad and Mac** (polish)  
  is the Mac version shipping, or should Catalyst be turned off

## training-library

- **1. Libraries open as sheets, and sheets then stack three and four deep** (hurts usability)  
  were the libraries made sheets on purpose (for example to keep the tab bar accessory out of the way)?
- **2. "Edit Workout" on a finished session opens no editor, and Save hides in the More menu** (hurts usability)  
  should a finished workout's sets be editable here?
- **15. A sheet to choose between three commands** (polish)  
  `showAddTrainingViewZoom` suggests other callers; confirm they can take a menu too.
- **16. Short option lists open a sheet, and the muscle picker is a grid of one image** (polish)  
  is muscle artwork planned?
