# Profile, settings, account management and paywalls: HIG review (2026-09-28)

Reviewed against the live HIG with the `apple-hig` skill, `--platform ios`.

**Pages read:** `designing-for-ios`, `settings`, `managing-accounts`, `sign-in-with-apple`,
`apple-in-app-purchase`, `privacy`, `app-icons`, `alerts`, `action-sheets`, `sheets`, `modality`,
`lists-and-tables`, `toggles`, `pickers`, `buttons`, `offering-help`, `accessibility`, `writing`,
plus `ratings-and-reviews`, `entering-data` and `text-fields` for findings 12, 13 and 15.

**Scope.** Code read: all of `Core/Profile/` (Account, EditUsername, About, Licences, AppIcon,
Legal, Tutorials, GeneralSettings, NutritionSettings, TrainingSettings), `Core/Paywalls/`,
`Core/Onboarding/3 - Subscription/`, and what they call into: `CoreInteractor.signOut` /
`deleteAccount`, `GlobalRouter`'s alert helpers, `StravaManager`, `PremiumAccess`,
`LegalDocument`, `CoreBuilder.ratingsModal`, and the pinned `SwiftfulAuthenticatingFirebase`
(1.0.14) and `SwiftfulPurchasing` (1.1.1) sources for deletion and purchase behavior.

**Not reviewed.** `ExerciseTemplateDetail` and `ExercisesView` were skimmed only (they are
training-library screens that happen to live under `Core/Profile/`). The ten `Edit*` equipment
screens were sampled (`EditBand`, `EditWeightRange`, `AddBand`, `AddCableMachineRange`), not read
one by one. The RevenueCat paywall's own UI is a package view and was not inspected. The
onboarding Strava step belongs to the onboarding review.

**Not checked.** This is a code review. Nothing was built or run, so Dark Mode, the largest text
sizes, VoiceOver, iPad and Mac Catalyst are all unverified. Findings that depend on runtime
behavior say so.

Paths are relative to `DialedIn/`. Findings are most serious first.

## Decisions built (2026-09-29, branch hig/profile)

| Decision | Status | What changed |
|---|---|---|
| 1 | built | "Why Subscribe?" says a subscription is required, with Sign Out and an Account row; the onboarding paywall has both in an Account menu (`PaywallExits`). A lapsed returning subscriber now lands on "Why Subscribe?" (`WelcomePresenter`). |
| 1a | not built (recorded) | TODO marker in `SubscriptionPresenter.onContinuePressed` where the app-managed trial will hook in. |
| 6 | built | About, exercise detail and the seven equipment lists push inside the Profile sheet without their Close buttons; Add forms stay sheets. Equipment edits under a pushed list save as they happen. The paywall from Profile stays a full-screen cover. |
| 7e | built | "Notification Settings" row in Profile's General section. |
| 10a | built | `DeleteAccount` module replaces the alert: what is deleted, 30 days, Apple billing with Manage Subscription, sign-in note, loading modal, "Account Deleted" then Done. Cancelling sign-in is silent (`SignInCancellation`). |
| 10b | built | "Compound" on both paywalls, same features as "Why Subscribe?", plans first with the first preselected and a checkmark, period from `Product.SubscriptionPeriod` formatting, Terms and Privacy under Restore. Profile's status reads Active/Inactive. |
| 10c | built | Knowledge Base, Roadmap, App Icon, Tutorials, Exercise Assessment and Premove hidden with a TODO each; Siri lists the four shipped App Shortcuts. |
| 10d | built in part | `ReviewMoment` rule, tests and `requestReviewIfEarned(_:)`; custom card deleted. The two call sites (workout finishing, food logging) are outside this area. |
| O1 | built | Daily Activity picker in Account, saved with the profile. Also: "Sex" with every `Gender` case, "Exercise Frequency" for "Lifting Experience", Strava sign-in cancel silent with fixed failure copy. |

## Resolution (2026-09-28, branch hig/profile)

| # | Status | What changed |
|---|---|---|
| 1 | fixed | Confirm button in Account's toolbar calls `saveProfile()` (spinner while saving, disabled without a first name); success/error haptics. Verified: no app caller before. |
| 2 | skipped: decision | — |
| 3 | needs a change elsewhere | `CoreInteractor.deleteAccount` passes `revokeToken: false`; the package revokes only when true. See the report. |
| 4 | skipped: decision | — |
| 5 | skipped: decision | Only the failure alert's title changed ("Unable to Delete Account"). |
| 6 | fixed | A subscriber gets Apple's `manageSubscriptionsSheet` (plan, price, renewal, cancel), not the paywall; status reads "Premium"/"Free". Redeem Code not added. |
| 7 | fixed | Cancel is a no-op, Ask to Buy shows an inline "Waiting for approval" on both variants, the load-failure alert is gone, other alerts have titles. The package's error type is internal, so it is matched by case name (`ponytail:` comment). |
| 8 | skipped: decision | — |
| 9 | fixed | Saves on `onDisappear` when edited (any route out), system back button restored, blank name saved as "Untitled Gym Profile", failure after leaving is a toast. |
| 10 | skipped: decision | Licenses is now pushed inside About (listed in the hand-offs); the rest waits on the decision. |
| 11 | fixed in scope | Presenter stores `stravaIsConnected` and refreshes it; Disconnect is its own row with a confirmation; Connect is borderless; Test Upload is `#if DEV \|\| MOCK` and toasts. Manager changes are needed elsewhere. |
| 12 | partly fixed | Modal deleted, row is "Rate Compound" and calls the system prompt directly. No App Store ID exists yet for the write-review URL. |
| 13 | fixed | All 17 fields labeled with their caption and a "0" placeholder; each `Add*` presenter exposes `validationMessage`, confirm is disabled until nil and the reason shows as `InlineMessage` under the fields. |
| 14 | fixed | "Sign-In Method" row (Apple / Google / Not saved); "Sign Out"; "Save Account". |
| 15 | fixed | Hours formatted with `Date.FormatStyle` (12/24-hour); Units defaults from `Locale.measurementSystem`; Account height typed in the Units length unit, converted on save. |
| 16 | skipped: decision | Exercise Assessment's subtitle was shortened under finding 17 only. |
| 17 | fixed | Five subtitles cut to one line, "On"/"Off"/"Show" removed, Previous Reference reads the stored option, the two static Strategy labels removed, "Keep Screen On". |
| 18 | fixed | Hour range, timestamp side and rest scaling are inline pickers; the start-date sheet has a close button that restores the old date. |
| 19 | fixed | The Edit link's label is padded to 44 pt. |
| 20 | fixed | Sections no longer gated on a first name; header says "Add your name". |
| Smaller | fixed | Paywall header scrolls; RevenueCat close button only in onboarding; only the custom paywall loads products; Reset Default Timers in its own section with a confirmation; distinct rest-scaling titles and Use Rest Timers first; Shortcuts footer and Favorites header reworded; Discard Gym Profile alert gone; date of birth capped at today; `Symbol.duration` removed from three unrelated rows; Profile, Food Log and Account strings localized. Not done: `FeatureUnavailableView(summary:)` strings (finding 16's screens). |
| Hand-offs | fixed | Every site listed for Core/Profile and Core/Paywalls in `hig-handoffs.md`, plus `FoodLogSettingsPresenter:134`. |

## Findings

### 1. Nothing on the Account screen can be saved
Severity: blocks people
Where: `Core/Profile/Subviews/Account/AccountView.swift:199-209` (toolbar has only the photo
button), `:90-134` (the editable fields); `AccountPresenter.swift:102` (`saveProfile()`)
Guideline: "If you provide a Done button, always pair it with a Cancel button to give people a
clear way to dismiss the sheet without confirming or saving their changes" —
https://developer.apple.com/design/human-interface-guidelines/sheets (the screen has neither).
Also "When necessary, help people avoid data loss" —
https://developer.apple.com/design/human-interface-guidelines/modality
What happens: first name, last name, date of birth, gender, height, cardio and lifting experience
and the profile photo are all live editors, but `saveProfile()` has no caller outside
`DialedInUnitTests`. Every edit is discarded when the person goes back, with no warning. A picked
photo shows in the header and is never uploaded. Only the privacy toggle and the username (its
own screen) persist.
Fix: add the contract's confirm item, as `EditUsernameView` already does:
```swift
ToolbarItem(placement: .confirmationAction) {
    if presenter.isSaving { ProgressView() } else {
        Button(role: .confirm) { Task { await presenter.saveProfile() } }
            .disabled(!presenter.canSave)
    }
}
```
Add `playHaptic(.success)` in `saveProfile()` per the contract.
Size: S
Decision needed: no

### 2. Someone who will not subscribe cannot delete their account, sign out, or leave the paywall
Severity: blocks people, App Review exposure
Where: `Core/Paywalls/Paywall/PaywallView.swift:70` (close button only when `!isOnboarding`);
`Core/Onboarding/3 - Subscription/SubscriptionView.swift:29` (back hidden),
`SubscriptionPresenter.swift:26`; `Core/Onboarding/0 - WelcomeView/WelcomePresenter.swift:54`;
`Core/Onboarding/2 - AuthView/AuthPresenter.swift:154-156`; the only route to deletion is
`Core/Profile/ProfilePresenter.swift:66`
Guideline: "Provide a clear way to initiate account deletion within your app or game." and "Even
if people didn't use your app to purchase the subscription, you still need to support account
deletion." — https://developer.apple.com/design/human-interface-guidelines/managing-accounts.
Also "Let people experience your app before making a purchase… consider supporting limited free
access to your content." —
https://developer.apple.com/design/human-interface-guidelines/apple-in-app-purchase
What happens: a signed-in non-subscriber is always routed to "Why Subscribe?" and then the
paywall. Sign Out and Delete Account exist only in Profile > Account, inside the app the paywall
guards. A person who signs in and declines, or a lapsed subscriber, has an account they cannot
delete or sign out of, and the custom and StoreKit paywalls offer no exit at all. Nothing on
either screen says a subscription is required to use the app.
Fix: on the onboarding paywall and on `SubscriptionView`, add a secondary "Sign Out" and an
account link that pushes `AccountView` (it needs no subscription). State plainly on
`SubscriptionView` that the app requires a subscription.
Size: M
Decision needed: yes — premium-only is a stated product decision (`PremiumAccess.swift:29`). Is
any free access or trial wanted, or only the exits?

### 3. Deleting an account does not revoke the Sign in with Apple token
Severity: blocks people (privacy), App Review exposure
Where: `Root/RIBs/Core/CoreInteractor.swift:237` (`revokeToken: false`)
Guideline: "If people used Sign in with Apple to create an account within your app, you revoke
the associated tokens when they delete their account." —
https://developer.apple.com/design/human-interface-guidelines/managing-accounts
What happens: the package revokes only when `revokeToken` is true
(`FirebaseAuthService.swift:127-129`). `functions/` has no server-side revocation either, so the
app stays listed under the person's "Apps using Apple Account" after deletion.
Fix: `revokeToken: auth.authProviders.contains(.apple)`. Note the package revokes after the user
document is deleted, so a revocation failure leaves a half-deleted account; catch it and continue
to `user.delete()` in the fork.
Size: S (M if the fork changes)
Decision needed: no

### 4. Every legal link opens apple.com
Severity: hurts usability (trust), blocks release
Where: `Utilities/Constants.swift:20-23`; shown by `Core/Profile/Subviews/Legal/LegalView.swift:37`
Guideline: "Be transparent about how your app collects and uses people's data." —
https://developer.apple.com/design/human-interface-guidelines/privacy. The purchase page expects
"links to your Terms of Service and Privacy Policy in your app" —
https://developer.apple.com/design/human-interface-guidelines/apple-in-app-purchase
What happens: Terms of Service, Privacy Policy, Health Disclaimer and Consumer Health Privacy all
resolve to `https://www.apple.com`. The code comment in `LegalDocument.swift:31` already says so;
it is listed here because it gates release and the paywall depends on it.
Fix: publish the four documents and replace the constants. Until then, show the rows disabled
(the view already handles a nil URL).
Size: S in code
Decision needed: yes — where the documents will be hosted

### 5. The deletion alert says nothing about the subscription, the re-authentication or the timing
Severity: hurts usability
Where: `Core/Profile/Subviews/Account/AccountPresenter.swift:222-236`, `:243-259`
Guideline: "If you support in-app purchases, help people understand how billing and cancellation
work when they delete their account… Billing for an auto-renewable subscription continues through
Apple until people cancel the subscription" and "Tell people when account deletion will complete,
and notify them when it's finished." —
https://developer.apple.com/design/human-interface-guidelines/managing-accounts
What happens: the alert reads "This action is permanent and cannot be undone. Your data will be
deleted from our server forever." Tapping Delete then raises the Apple or Google sign-in sheet
with no warning, runs with no progress indicator, and on success silently switches to onboarding
a second later. The rest of the data is deleted later by the `onUserDeleted` function, which is
never mentioned. Cancelling the sign-in sheet produces an alert titled "Error". A subscriber is
still billed and is not told.
Fix: replace the alert with a short confirmation screen: what is deleted, that deletion is
immediate and the remaining data follows within a stated time, "Your subscription is billed by
Apple and is not cancelled by deleting your account" with a Manage Subscription button
(`manageSubscriptionsSheet`), and "You'll be asked to sign in again to confirm". Wrap the work in
`router.showLoadingModal()` and show a final "Account deleted" message before switching module.
Size: M
Decision needed: yes — the time limit to state for server-side deletion

### 6. The Subscription row sells to people who already subscribe, and nothing manages a subscription
Severity: hurts usability
Where: `Core/Profile/ProfilePresenter.swift:77-84`, `Core/Profile/ProfileView.swift:87`
Guideline: "Encourage a new subscription only when someone isn't already a subscriber. Otherwise,
people may believe their existing subscription has lapsed", "Provide summaries of the customer's
subscriptions… people appreciate viewing the upcoming renewal date" and "Always make it easy for
customers to cancel an auto-renewable subscription." —
https://developer.apple.com/design/human-interface-guidelines/apple-in-app-purchase
What happens: the row shows "PREMIUM" and, tapped, presents the full paywall with Subscribe. No
call to `showManageSubscriptions`, `manageSubscriptionsSheet`, `offerCodeRedemption` or
`beginRefundRequest` exists anywhere in `DialedIn/`.
Fix: when `isPremium`, open a small Subscription screen: plan name, price, renewal date, then
Manage Subscription, Restore Purchases and Redeem Code. Keep the paywall for non-subscribers.
Write the status in title case ("Premium").
Size: M
Decision needed: no

### 7. Cancelling a purchase, or Ask to Buy, raises an "Error" alert
Severity: hurts usability
Where: `Core/Paywalls/Paywall/PaywallPresenter.swift:141-158` (custom paywall), `:174-175`
(StoreKit paywall, pending); generic alert at `Root/RIBs/GlobalRouter.swift:40`, used at
`PaywallPresenter.swift:70`, `:126`, `:155` and `AccountPresenter.swift:53`, `:209`, `:255`
Guideline: "Avoid writing a title that doesn't convey useful information — like 'Error'" and
"Use alerts sparingly" — https://developer.apple.com/design/human-interface-guidelines/alerts.
"Use the default confirmation sheet." —
https://developer.apple.com/design/human-interface-guidelines/apple-in-app-purchase
What happens: on the custom paywall (the default variant) `StoreKitPurchaseService` throws
`userCancelledPurchase` when the person closes Apple's sheet and `failedToPurchase` when the
purchase is pending approval. The presenter treats both as failures: error haptic, then an alert
titled "Error" with a system-generated message. On the StoreKit paywall a pending purchase is
logged and the person is told nothing. A failed product load shows the inline error state and an
alert for the same failure.
Fix: treat cancel as a no-op; for pending show "Waiting for approval" inline. The package's error
type is internal, so either match it in the fork or add a public case. Drop the alert at `:70`;
the inline state already covers it. Give `showAlert(error:)` callers a specific title.
Size: M
Decision needed: no

### 8. The custom paywall does not say what is being bought
Severity: hurts usability, App Review exposure
Where: `Core/Paywalls/Paywalls/CustomPaywallView.swift:14-15`, `:62`, `:88`;
`Core/Paywalls/Paywalls/StoreKitPaywallView.swift:19-29`; `Core/Profile/ProfilePresenter.swift:78`
Guideline: "the in-app sign-up screen needs to include: the subscription name, duration, and the
content or services provided during each subscription period; the billing amount, correctly
localized…; a way for existing subscribers to sign in or restore purchases" and "Clearly describe
how a free trial works." —
https://developer.apple.com/design/human-interface-guidelines/apple-in-app-purchase.
"Build language patterns. Consistency builds familiarity" —
https://developer.apple.com/design/human-interface-guidelines/writing
What happens:
- The heading is "Try Premium Today!" though no trial is described. If the products carry an
  introductory offer, `AnyProduct` cannot show it.
- The benefits line is "Unlock unlimited access and exclusive features for premium members."
  It names no feature.
- The product is "Premium" here, "Compound Pro" on the StoreKit variant and "PREMIUM" in Profile.
- Each plan card carries a "Start" chip that starts nothing; it only selects.
- Price reads "$9.99 / month" from `priceStringWithDuration`, which appends the raw English enum
  value, so the period is not localized in the Spanish build.
- Neither variant links Terms or Privacy (and see finding 4).
- `title` and `subtitle` are `String`, so `Text` does not localize them.
Fix: one product name everywhere. Heading "Compound Premium"; list the same features as
`SubscriptionView`. Replace the chip with the row's selection checkmark and preselect the first
plan. Format the period with `Product.SubscriptionPeriod` formatting. Add the two links under
Restore; on the StoreKit view use `.storeButton(.visible, for: .policies)` with
`.subscriptionStorePolicyDestination`.
Size: M
Decision needed: yes — the product's name, and whether a trial exists

### 9. Swiping the Profile sheet away discards gym profile edits
Severity: hurts usability (data loss)
Where: `Core/Profile/ProfileView.swift:207` (`.sheet`);
`…/GymProfiles/GymProfile/GymProfilePresenter.swift:94-117` (save runs only from the custom Back
button, Continue and the photo picker); `GymProfileView.swift:94`, `:323-330`
Guideline: "If people have unsaved changes in the sheet when they begin swiping to dismiss it,
use an action sheet to let them confirm their action." —
https://developer.apple.com/design/human-interface-guidelines/sheets
What happens: equipment toggles, the name and every weight added in the `Edit*`/`Add*` sheets
live in the presenter until Back is tapped. The gym screen is pushed inside the Profile sheet, and
nothing in scope sets `interactiveDismissDisabled`, so a downward swipe closes Profile and drops
the changes. The hidden system back button also removes the edge-swipe back gesture (my judgment).
Fix: save on change like every other settings screen here (debounced), and restore the system
back button. The "needs a name" alert can then move to the Continue/leave path only.
Size: M
Decision needed: no

### 10. Settings is a modal that stacks three more modals
Severity: hurts usability
Where: `Core/Profile/ProfileView.swift:207`; `Core/Profile/Subviews/About/AboutView.swift:73`
(sheet) then `About/Licences/LicencesView.swift:81` (full-screen cover);
`…/EditBand/EditBandView.swift:110` (sheet) then `…/AddBand/AddBandView.swift:105` (sheet), the
same for the other equipment types; `Core/Paywalls/Paywall/PaywallView.swift:96`
Guideline: "Display only one sheet at a time from the main interface… If closing a sheet takes
people back to another sheet, they can lose track of where they are" —
https://developer.apple.com/design/human-interface-guidelines/sheets. "Take care to avoid
creating a modal experience that feels like an app within your app. In particular, presenting a
hierarchy of views within a modal task can make people forget how to retrace their steps." —
https://developer.apple.com/design/human-interface-guidelines/modality
What happens: Profile is a sheet holding about 45 pushed screens. About is a sheet on that sheet
and Licenses a cover on top of both. Adding a band is sheet, push, push, sheet, sheet.
Fix: push About and Licenses. Push the `Edit*` screens and keep only the `Add*` form as a sheet.
That leaves at most one modal above Profile.
Size: M
Decision needed: yes — whether Profile itself should stay a sheet or become a pushed screen

### 11. Strava: Disconnect is one stray tap away, the row does not update, and a test button ships
Severity: hurts usability
Where: `Core/Profile/Subviews/GeneralSettings/Integrations/IntegrationsView.swift:28`, `:53`,
`:56`; `IntegrationsPresenter.swift:39-41`, `:49`; `Managers/Strava/StravaManager.swift:20`,
`:67-71`
Guideline: "Provide appropriate feedback when people select a list item." —
https://developer.apple.com/design/human-interface-guidelines/lists-and-tables. "a button needs a
hit region of at least 44x44 pt" — https://developer.apple.com/design/human-interface-guidelines/buttons.
"Be transparent about how your app collects and uses people's data." — privacy page
What happens:
- `isConnected` is computed from the Keychain, which Observation does not track, and
  `onStravaDisconnectPressed` changes no observed state. The row should keep saying "Connected"
  after Disconnect until something else redraws it (not run).
- The Connect/Disconnect and Test Upload buttons use the default style inside a `List` row, so
  the whole row becomes the button (not run; `GymProfileView.swift:432-434` documents the same
  trap and uses `.borderless`). There is no confirmation.
- "Test Upload" posts an activity named "DialedIn Test Upload" to the person's real Strava
  account. The app's name is Compound.
- `disconnect()` deletes local tokens only, and neither `signOut()` nor `deleteAccount()` calls
  it, so the tokens (stored synchronizable) outlive the account and pass to the next person who
  signs in on the device. (The privacy tie is my judgment.)
Fix: make `isConnected` a stored property set in `storeTokens`/`disconnect`. Put Disconnect in
its own destructive row with a confirmation dialog. Move Test Upload behind `#if DEV || MOCK`.
Call `disconnect()` from sign-out and deletion, and deauthorize at Strava.
Size: M
Decision needed: no

### 12. "Rate us" asks "Are you enjoying AIChat?"
Severity: hurts usability
Where: `Root/RIBs/Core/CoreBuilder.swift:24`; `Core/Profile/ProfilePresenter.swift:146-164`;
`Core/Profile/ProfileView.swift:159`
Guideline: "Prefer the system-provided prompt… The system automatically limits the display of
the prompt to three occurrences per app within a 365-day period." and "People can always rate
your app within the App Store." —
https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews
What happens: the row opens a custom modal naming another app, with Yes and No. Yes calls
`requestRatingsReview()`, which the system may decline to show, so a person who asked to rate can
see nothing happen. No ends the flow. Asking for sentiment first and sending only "Yes" to the
rating is a review risk (my judgment).
Fix: delete the modal. Open the App Store review page directly
(`https://apps.apple.com/app/id<ID>?action=write-review`). Title the row "Rate Compound".
Size: S
Decision needed: no

### 13. Seven add-equipment forms have unlabeled fields and validate by alert
Severity: hurts usability (accessibility)
Where: 17 `TextField("", …, prompt: Text(""))` in 8 files, including
`…/EditBand/AddBand/AddBandView.swift:51`, `:63`;
`…/EditCableMachine/AddCableMachineRange/AddCableMachineRangeView.swift:42`, `:53`, `:67`, `:81`;
`…/EditPinLoadedMachine/AddPinLoadedMachineRange/AddPinLoadedMachineRangeView.swift:42`, `:53`,
`:67`, `:81`; `…/EditWeightRange/EditWeightRangeView.swift:21`, `:33`, `:46`;
`AddBodyWeightView.swift:38`, `AddLoadableBarView.swift:38`, `AddFreeWeightView.swift:51`,
`AddFixedWeightBarView.swift:38`. Alerts: 14 "Unable to add" calls in the seven `Add*Presenter`s,
for example `AddBandPresenter.swift:71`, `:75`
Guideline: "verify that… your interface elements are appropriately labeled" —
https://developer.apple.com/design/human-interface-guidelines/accessibility. "Dynamically
validate field values" and "make the button available only after people enter the data you
require" — https://developer.apple.com/design/human-interface-guidelines/entering-data. "Show a
hint in a text field" — https://developer.apple.com/design/human-interface-guidelines/text-fields
What happens: the visible caption is a sibling `Text`, so the field itself has an empty label for
VoiceOver and Voice Control, and no placeholder. The confirm button is always enabled; a missing
name or duplicate weight is reported by an alert after the tap.
Fix: use the contract's `NumberField(value:unit:label:)` and a labeled `TextField`. Disable
confirm until the form is valid and show the reason with `InlineMessage` under the field.
Size: M
Decision needed: no

### 14. Account does not say how the person is signed in
Severity: hurts usability
Where: `Core/Profile/Subviews/Account/AccountView.swift:164-191`
Guideline: "Indicate when people are currently signed in. You can help people confirm their
sign-in method by displaying a phrase like 'Using Sign in with Apple' in places like a settings
or account interface." —
https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple
What happens: the Security section shows only an Email row. An anonymous account reads "Email:
Not provided". `auth.authProviders` is already available (`CoreInteractor.swift:230`).
Fix: add a read-only "Sign-In Method" row: "Apple", "Google" or "Not saved" for anonymous. Rename
"Log Out" to "Sign Out" and "Save & back-up account" to "Save Account" to match the sign-in
wording.
Size: S
Decision needed: no

### 15. Three settings ignore what the system already knows
Severity: hurts usability
Where: `Core/Profile/Subviews/NutritionSettings/FoodLogSettings/FoodLogSettingsView.swift:176-183`
and `FoodLogSettingsPresenter.swift:88-95` (hard-coded "AM"/"PM");
`Core/Profile/Subviews/GeneralSettings/Units/UnitsPresenter.swift:38-45` (defaults to metric);
`Core/Profile/Subviews/Account/AccountView.swift:107-116` (height in cm only)
Guideline: "Respect people's systemwide settings" and "Avoid using settings to ask for setup
information you can get in other ways." —
https://developer.apple.com/design/human-interface-guidelines/settings. "Get information from the
system whenever possible." — https://developer.apple.com/design/human-interface-guidelines/entering-data
What happens: the hour range is always 12-hour, whatever the device's 24-hour setting. Unit
preferences fall back to kilograms and centimeters; `Locale.measurementSystem` is used nowhere in
`DialedIn/`. The Account height field takes centimeters even when Units is set to Feet & Inches.
Fix: format hours with `Date.FormatStyle` (`.dateTime.hour()`). Default units from
`Locale.current.measurementSystem`. Drive the height field from `LengthUnitPreference`, converting
on save.
Size: M
Decision needed: no

### 16. Seven rows lead to a screen or alert that says the feature does not exist
Severity: hurts usability
Where: `Core/Profile/ProfileView.swift:99` (Siri), `:150` (Knowledge Base), `:153` (Roadmap),
`:172` (App Icon), `:175` (Tutorials);
`…/WorkoutSettings/WorkoutSettingsView.swift:128-134` (Exercise Assessment);
`…/FoodLogSettings/FoodLogSettingsView.swift:63-68` (the Premove toggle, which nothing reads)
Guideline: "Minimize the number of settings you offer… too many settings can make the experience
feel less approachable, while also making it hard to find a particular setting." — settings page.
"Avoid using an alert merely to provide information." — alerts page. "Choose simple, plain
language… avoiding jargon" — https://developer.apple.com/design/human-interface-guidelines/writing
What happens: Knowledge Base and Roadmap raise alerts saying there is no site. The others open a
`FeatureUnavailableView`. Two of those explain themselves in developer terms: "It needs an App
Intents extension, which the app does not ship" and "There is only one icon set in the asset
catalog". The Siri screen is also wrong: `DialedInAppShortcuts` ships four App Shortcuts and the
Shortcuts screen links to them. Exercise Assessment's row describes a questionnaire; its screen
describes test lifts. `premove` is stored and read nowhere.
Fix: remove the seven rows until the features exist. `FeatureUnavailableView` stays for screens
reached some other way. If any row is kept, rewrite the copy without implementation detail.
Size: S
Decision needed: yes — whether the rows are kept as a visible roadmap

### 17. Settings copy: truncated explanations, state repeated as a subtitle, a stale value
Severity: polish
Where: subtitles over about 80 characters under the row's two-line cap:
`…/WorkoutSettings/WorkoutSettingsView.swift:114` (133 characters), `:130` (110),
`…/ExpenditureSettings/ExpenditureSettingsView.swift:41` (103), `:49` (89),
`…/SmartProgressionSettings/SmartProgressionSettingsView.swift:20` (88). State as subtitle:
`FoodLogSettingsView.swift:53`, `:59` ("Show"), `:76`, `:81` and
`…/StrategySettings/StrategySettingsView.swift:24` ("On"/"Off"). Stale value:
`WorkoutSettingsView.swift:49` (always "Any Workout"). Non-interactive rows styled as settings:
`StrategySettingsView.swift:36`, `:69`. Label: `WorkoutSettingsView.swift:88-89` ("Keep Alive")
Guideline: "Keep settings labels clear and simple… If the setting label isn't enough, add an
explanation. Describe what it does when turned on, and people can infer the opposite." — writing
page. "Keep item text succinct so row content is comfortable to read… minimize truncation" —
https://developer.apple.com/design/human-interface-guidelines/lists-and-tables
What happens: the longest explanations are cut off at two lines at default text size (not run).
A toggle that is on says "On" beneath its title. Previous Reference shows "Any Workout" whatever
is selected. "Introduction" and "Program Update" look like rows and do nothing.
Fix: cut each subtitle to one sentence of about 60 characters or move it to the section footer.
Delete the "Show"/"On"/"Off" subtitles. Read the Previous Reference subtitle from
`previousWorkoutReference.title`. Remove the two static labels. Rename to "Keep Screen On".
Size: S
Decision needed: no

### 18. Pickers presented as sheets have no way to cancel, and one choice is an alert
Severity: polish
Where: `FoodLogSettingsView.swift:166-172` and `ExpenditureSettingsView.swift:116-120` (confirm
only); `…/RestTimerSettings/RestTimerSettingsView.swift:128-138` (no toolbar button);
`FoodLogSettingsPresenter.swift:132-146` (Left/Right offered in an alert from a chevron row)
Guideline: "Provide an alternative to the Done button… Relying solely on the Done button implies
that completing the task is the only way to exit the sheet" — sheets page. "Use an action sheet —
not an alert — to offer choices related to an intentional action." and "Avoid switching views to
show a picker." — alerts and https://developer.apple.com/design/human-interface-guidelines/pickers
What happens: the hour and start-date sheets apply each change live and offer only a checkmark.
The scaling sheet offers nothing but the swipe. Timestamp side is a two-option alert.
Fix: make hour range, scaling and timestamp side inline `Picker` rows (the WP-12 reference
pattern in `UnitsView`). For the date, add `role: .close` in `.cancellationAction` that restores
the previous value.
Size: S
Decision needed: no

### 19. "Edit Weights" is a text link about 20 pt tall
Severity: polish
Where: `…/GymProfiles/GymProfile/GymProfileView.swift:467-472`
Guideline: "a button needs a hit region of at least 44x44 pt" — buttons page
What happens: a `.rowDetail` borderless button sits between the detail text and a switch, with no
padded hit area (not run).
Fix: make the row a `ListRowButton` that opens the editor and keep the switch as its trailing
accessory, or pad the link's `contentShape` to 44 pt as `.chipTapTarget()` does.
Size: S
Decision needed: no

### 20. Profile is blank when the first name is missing
Severity: polish
Where: `Core/Profile/ProfileView.swift:17-30`
Guideline: "Provide clear next steps on any blank screens." — writing page
What happens: every section, including the header that leads to Account, is inside
`if let firstName…, !firstName.isEmpty`. Before the user document arrives, or for a profile
without a name, the sheet shows a title and a close button and nothing else. Onboarding requires
a name, so this is an edge case, but it also hides Sign Out and Delete Account.
Fix: drop the name condition from the settings sections. Show the header with a "Add your name"
placeholder when the name is empty.
Size: S
Decision needed: no

## Smaller items

- `CustomPaywallView.swift:34-47` plus a three-part bottom inset leaves the plan list little room
  on a small phone at large text sizes (not run). Let the header scroll with the list.
- `RevenueCatPaywallView.swift:14` always passes `displayCloseButton: true`, so outside
  onboarding that variant has two close buttons (`PaywallView.swift:70-75`).
- `PaywallView.swift:66` loads products for the StoreKit and RevenueCat variants too, which load
  their own.
- `…/TimerDuration/TimerDurationView.swift:25-31` "Reset Defaults" sits among the rows it resets,
  looks like them, and resets at once with no confirmation.
- `RestTimerSettingsView.swift:47`, `:97` and the two pairs below them give two different rows
  the same title on one screen. "Use Rest Timers" is the master switch but sits in the second
  section, under "Notifications".
- `ShortcutsView.swift:30` and `FavouriteMeasurementsView.swift` (header "Tap to toggle a
  measurement as a favorite") explain standard controls; the offering-help page advises against
  it.
- `GymProfilePresenter.swift:97` alert title "Discard Gym Profile" is not a question, and for an
  existing profile Discard only abandons the edit.
- `AccountView.swift:95` lets the date of birth be in the future; add `in: ...Date()`.
- `FoodLogSettingsView.swift:48-66` uses `Symbol.duration` for five different settings, against
  the contract's "one symbol, one concept".
- Several strings reach `Text` or an alert as `String` and are not localized:
  `ProfilePresenter.swift:101`, `:115`, `:123`, `FoodLogSettingsPresenter.swift:25-27`, every
  `FeatureUnavailableView(summary:)`, `AccountPresenter.swift:152`.
- Already reported in the onboarding review: "HealthKit sync" at `SubscriptionView.swift:25`.

## Contract conflicts

- **Destructive role on a confirmation the person asked for.** `CONTRACT.md` § Patterns says
  irreversible actions use `Button(role: .destructive)` in the confirming alert
  (`AccountPresenter.swift:228`, `GymProfilesPresenter.swift:67`). The HIG says: "Use the
  destructive style to identify a button that performs a destructive action people didn't
  deliberately choose. For example, when people deliberately choose a destructive action — such
  as Empty Trash — the resulting alert doesn't apply the destructive style" —
  https://developer.apple.com/design/human-interface-guidelines/alerts. The example reasons from
  pressing Return on a Mac, so it matters most for Catalyst. Reported only; the contract stands.

## Done well — keep

- Delete Account is one level below Profile, in plain sight, uses the destructive role, and its
  alert has a Cancel.
- An anonymous account is offered "Save & back-up account" in place of Log Out, so it cannot lock
  itself out of its data.
- The Email row is read-only and shows the address the provider supplied, so a private relay
  address can be found in the app, as the Sign in with Apple page asks.
- The custom paywall states the auto-renewal price next to Subscribe, disables Subscribe until a
  plan is chosen, and tells the person when Restore finds nothing and why.
- The StoreKit paywall uses `SubscriptionStoreView` with the restore button visible.
- Settings save on change with no Save button, and each screen reports a failed save.
- Username editing validates as the person types, inline, and disables confirm until the name is
  available.
- Deleting a gym profile or an exercise asks first; Shortcuts uses the standard Edit mode for
  reorder and delete.
- Equipment color swatches have VoiceOver names and the selected trait.
- Every close button uses `role: .close` in `.cancellationAction`.
