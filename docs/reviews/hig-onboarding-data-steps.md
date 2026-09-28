# Onboarding data-entry and goal-setting steps: HIG review (2026-09-28)

Reviewed against the live HIG with the `apple-hig` skill, `--platform ios`.

**Pages read:** `designing-for-ios`, `onboarding`, `entering-data`, `pickers`, `text-fields`,
`virtual-keyboards`, `segmented-controls`, `sliders`, `steppers`, `inclusion`, `writing`,
`privacy`, `sign-in-with-apple` (Collecting data), `progress-indicators`, `page-controls`,
`accessibility`, `charting-data`, plus `charts`, `color`, `voiceover`, `alerts`, `toggles`,
`feedback` and `launching` where the code needed them.

**Scope.** Code read, all under `Core/Onboarding/`: `4 - CompleteAccountSetup/` (the container
and steps `1 - NamePhoto` to `9 - Expenditure`), `5 - HealthDisclaimer/`, all of
`6 - GoalSetting/`, all of `8 - OnboardingDiet/`, `9 - OnboardingCompleted/`,
`9 - StravaConnect/`, `Components/`, `OnboardingStepRouter.swift`, and
`Components/DesignSystem/OnboardingStepScaffold.swift`. Read for context only:
`Managers/User/Models/UserModel.swift`, `Components/Modals/CustomModalView.swift`,
`Components/Buttons/CallToActionButton.swift`, `Utilities/LegalDocument.swift`,
`Managers/Strava/StravaManager.swift`, `Managers/Nutrition/NutritionManager/NutritionManager.swift`,
`Localizable.xcstrings`.

**Not reviewed.** Steps 0, 1, 2, 3 and the permission steps 4/10 and 4/11 (covered by
`docs/reviews/onboarding-hig-review.md`), the gym-profile and training-program steps that sit
between goal setting and the diet steps, and the design-system primitives themselves
(`SelectableRow`, `CallToActionButton`, `.bottomCTA`).

**Tree state.** Other people were editing this tree during the review. The two permission
steps (4/10, 4/11) were deleted and the four `9 - Expenditure` files changed part-way through.
Every `path:line` below was re-checked against the tree after those edits landed.

**Not checked.** This is a code review. Nothing was built or run, so Dark Mode, the largest
Dynamic Type sizes, VoiceOver, iPad and Mac Catalyst are all unverified. Contrast figures are
computed from the system colour values on the HIG `color` page, not measured on a device. Two
layouts are worth running at accessibility sizes before anything else: the seven-column
`WeeklyMacroChart` (each column carries a caption-size calorie figure in about 40 pt) and the
label/value rows in `ExpenditureView`'s "How we calculated this" section.

Paths are relative to `DialedIn/`; `…/` stands for `Core/Onboarding/`. Findings are most serious
first.

## Findings

### 1. The goal steps accept and display unsafe values with no feedback
Severity: hurts usability (health and safety)
Where: `…/6 - GoalSetting/3 - WeightRate/WeightRatePresenter.swift:36-37`, `:118-123`;
`WeightRateView.swift:56-66`, `:84`; `…/2 - TargetWeight/TargetWeightPresenter.swift:66-74`, `:86-100`
Guideline: "Dynamically validate field values… When you verify values as soon as people enter
them — and provide feedback as soon as you detect a problem — you give them the opportunity to
correct errors right away." — https://developer.apple.com/design/human-interface-guidelines/entering-data
Also "Be clear. Choose words that are easily understood and convey the right thing." —
https://developer.apple.com/design/human-interface-guidelines/writing
What happens: the rate slider runs from 0.25 to 1.5 kg a week for everybody, whatever they
weigh, and for gaining as well as losing. The "estimated daily calorie target" under it is
computed from a hard-coded `baseCalories = 2000.0`, not from the expenditure the app showed the
same person four screens earlier, and no floor is applied. At the top of the slider it reads
"~ 346 kcal estimated daily calorie target". The only signal is the heading changing to
"Aggressive". Separately, the target-weight wheel offers every adult who chose "Lose weight" a
target down to 30 kg (66 lb), with no check against height. That these values are unsafe is my
judgment, not a HIG statement; the missing validation and the wrong figure are the HIG part.
Fix: compute the estimate from the user's own expenditure (the Mifflin-St Jeor figure from step
4/9) and clamp it at the calorie floor. Cap the slider by body weight, for example 1% of body
weight a week, instead of a fixed 1.5 kg. When the rate is in the aggressive band, show an
`InlineMessage(.warning, …)` that says what the consequence is. Bound the target-weight wheel by
a height-derived minimum and say why the wheel stops there.
Size: M
Decision needed: yes — what the maximum weekly rate and the lowest selectable target should be,
and whether they depend on body weight and height.

### 2. People are asked to accept a privacy notice the screen neither shows nor links
Severity: hurts usability (trust), App Review exposure
Where: `…/5 - HealthDisclaimer/HealthDisclaimerView.swift:27-35`;
`HealthDisclaimerPresenter.swift:21-25`; `HealthDisclaimerRouter.swift:20-38`;
`Utilities/LegalDocument.swift:35-46`
Guideline: "Be transparent about how your app collects and uses people's data. People are less
likely to be comfortable sharing data with your app if they don't understand exactly how you
plan to use it." — https://developer.apple.com/design/human-interface-guidelines/privacy
Also "Avoid displaying licensing details within your onboarding flow… If you must include these
items within the onboarding flow, integrate them in a balanced way that doesn't disrupt the
experience." — https://developer.apple.com/design/human-interface-guidelines/onboarding
What happens: the second toggle reads "I acknowledge and accept the Terms of the Consumer
Health Privacy Notice", but only the health disclaimer's text is on the screen. There is no
link to the notice; `LegalDocument.consumerHealthPrivacy` exists and is used only by the Profile
legal list, and its URL is still the `apple.com` placeholder. Consent then takes four steps:
two toggles, Continue, and a custom modal that repeats both statements and can also be
dismissed by tapping outside it. The disclaimer and the modal call the app "DialedIn"; the
installed app is called "Compound". The disclaimer is a plain `String`, so it is shown in
English to Spanish users.
Fix: add a `Link` to each document beside its toggle (`LegalDocument.healthDisclaimer.url`,
`.consumerHealthPrivacy.url`) and publish the real documents. Drop the confirmation modal: the
two toggles plus Continue already record a deliberate choice. Replace "DialedIn" with the
display name, and move the disclaimer into `Localizable.xcstrings`.
Size: M
Decision needed: yes — the real document URLs, and whether legal needs the second confirmation.

### 3. Gender is required, offers two options, and gives no reason
Severity: hurts usability (inclusion)
Where: `…/4 - CompleteAccountSetup/2 - Gender/GenderView.swift:16-17`, `:23`;
`Managers/User/Models/UserModel.swift:404-406`;
`…/9 - Expenditure/ExpenditurePresenter.swift:84`
Guideline: "Most apps and games don't need to know a person's gender, but if you require this
information — such as for health or legal reasons — consider providing inclusive options, such
as nonbinary, self-identify, and decline to state." —
https://developer.apple.com/design/human-interface-guidelines/inclusion
What happens: the screen asks "What's Your Gender?" and lists Male and Female. Continue stays
disabled until one is picked. The value is used for one thing, the sex coefficient in the
Mifflin-St Jeor equation (`+5` or `−161`), and the screen does not say so. The explanation
appears seven screens later, in a footer ("BMR uses your age, height, weight and sex").
Fix: ask what the formula needs and say why: title "Sex for Calorie Estimate", subtitle "Used
only to estimate the calories you burn." Add a third option such as "Prefer not to say" that
uses the midpoint coefficient (−78). This needs a `Gender` case or an optional, so it touches
the model and the expenditure maths.
Size: M
Decision needed: yes — which options to offer and what coefficient the non-binary and
decline-to-state options use.

### 4. No data-entry step says why it is asking or whether the answer is required
Severity: hurts usability
Where: `…/3 - DateOfBirth/DateOfBirthView.swift:26-32`; `…/4 - Height/HeightView.swift:34`;
`…/5 - Weight/WeightView.swift:36`; `…/6 - ExerciseFrequency/ExerciseFrequencyView.swift:40`;
`…/7 - Activity/ActivityView.swift:42-43`; `…/8 - CardioFitness/CardioFitnessView.swift:45-46`;
`…/2 - Gender/GenderView.swift:16-17`
Guideline: "Clarify whether the additional data you request is required or just recommended…
If additional data isn't required but can improve the user experience, make sure people know
the request is optional and help them understand the benefits of providing the information."
and "describing why you need additional data" —
https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple
What happens: seven consecutive screens collect date of birth, sex, height, weight and three
activity ratings. Only the name step explains itself and marks its optional fields. The others
have a question for a title and nothing else. Cardio fitness is collected and saved
(`ExpenditurePresenter.swift:227`) but is not an input to the expenditure shown on the next
screen, so its purpose is not visible at all.
Fix: pass a `subtitle` to `OnboardingStepScaffold` on each step, one sentence each: what the
value feeds ("Used to estimate the calories you burn each day") and that it can be changed
later in Profile. If cardio fitness has no consumer yet, remove the step.
Size: S per screen, M in total
Decision needed: yes — whether cardio fitness stays.

### 5. Units start as metric for everyone, and the choice is asked twice
Severity: hurts usability
Where: `…/4 - Height/HeightPresenter.swift:16`; `…/5 - Weight/WeightPresenter.swift:16`;
`HeightView.swift:50-53`; `WeightView.swift:52-55`
Guideline: "Get information from the system whenever possible. Don't ask people to enter
information that you can gather automatically — such as from settings" —
https://developer.apple.com/design/human-interface-guidelines/entering-data
Also "People expect to customize their device by choosing a language for text and a region for
formatting values" — https://developer.apple.com/design/human-interface-guidelines/inclusion
What happens: both presenters default to metric (`unit = .centimeters`, `unit = .kilograms`).
Nothing under `DialedIn/` reads `Locale.measurementSystem`. Someone in the US switches to
Imperial on the height screen, then finds the weight screen back on Metric, because
`WeightPresenter` ignores the `lengthUnitPreference` it was handed.
Fix:
```swift
// HeightPresenter
var unit: UnitOfLength = Locale.current.measurementSystem == .metric ? .centimeters : .inches
// WeightPresenter: seed from the height step's choice in onAppear(delegate:)
unit = delegate.lengthUnitPreference == .centimeters ? .kilograms : .pounds
```
Size: S
Decision needed: no

### 6. The rate slider's end labels are unitless kilograms, and its value is not described
Severity: hurts usability
Where: `…/6 - GoalSetting/3 - WeightRate/WeightRateView.swift:56-68`
Guideline: "Consider supplementing a slider with a corresponding text field and stepper.
Especially when a slider represents a wide range of values, people may appreciate seeing the
exact slider value and having the ability to enter a specific value" —
https://developer.apple.com/design/human-interface-guidelines/sliders
Also "System-provided controls have generic labels by default, but you should provide more
descriptive labels that convey your app's functionality." —
https://developer.apple.com/design/human-interface-guidelines/voiceover
What happens: the minimum and maximum labels print `minWeightChangeRate` and
`maxWeightChangeRate` directly, which are kilograms, with one decimal and no unit. A person
using pounds sees "0.2" and "1.5" at the ends of a slider whose readout below is in pounds
(0.55 to 3.31 lb). 0.25 also rounds to "0.2" or "0.3". No `accessibilityValue` is set, so
VoiceOver will most likely read the position as a percentage rather than a rate (not run).
There are 26 stops and no way to step one at a time.
Fix: format the end labels with `Format.weight(kg:unit:)`; add
`.accessibilityValue(presenter.weeklyWeightChangeText(delegate: delegate))`; put a `Stepper`
with the same 0.05 step beside the readout.
Size: S
Decision needed: no

### 7. Spanish users get the wrong goal message, and several strings never reach the catalog
Severity: hurts usability
Where:
- `…/4 - GoalSummary/GoalSummaryPresenter.swift:155-171` (logic keyed on an English word)
- `…/9 - Expenditure/ExpenditurePresenter.swift:61-64`, `:114-118` (bare `String`s)
- `…/Components/WeeklyMacroChart.swift:14`, `:47` (hard-coded "Mon"…"Sun")
- `…/8 - OnboardingDiet/6 - DietPlan/DietPlanView.swift:86-90` (raw identifiers)
- `…/3 - WeightRate/WeightRatePresenter.swift:94`, `:104` (`String(format:)`), `:137`
- `…/4 - GoalSummary/GoalSummaryView.swift:93` ("/week"), `:106` (no plural variation)
- `…/5 - HealthDisclaimer/HealthDisclaimerPresenter.swift:21-25`
Guideline: "People expect to customize their device by choosing a language for text and a
region for formatting values like date, time, and money." —
https://developer.apple.com/design/human-interface-guidelines/inclusion
Also "Don't assume the actual presentation of data, however, as formatting can vary
significantly based on people's locale." —
https://developer.apple.com/design/human-interface-guidelines/text-fields
What happens: `objectiveIcon` and `motivationalMessage` test
`objective.description.lowercased().contains("lose")`. `description` is localized ("Perder
peso", "Mantener"), so in Spanish neither test matches and every goal gets the up arrow and
the "Building healthy weight takes time" message, including for someone losing weight. The
expenditure breakdown names and activity descriptions are plain `String`s and have no catalog
entry ("Basal Metabolic Rate", "Mostly sitting; little movement" are both missing from
`Localizable.xcstrings`). The chart's day names are English and assume a Monday start. The diet
summary prints enum raw values through `.capitalized`, giving "Preferred diet: Lowfat" and
"Protein: Veryhigh" in every language. `String(format: "%.2f")` always uses a full stop as the
decimal separator. "%lld weeks (%lld months)" has no plural variation, so it reads
"1 weeks (1 months)".
Fix: `switch objective` on the enum in both functions. Wrap the bare strings in
`String(localized:)`. Take day names from `Calendar.current.shortWeekdaySymbols`. Show
`PreferredDiet.description` and its siblings, not `rawValue.capitalized`. Replace
`String(format:)` with `.formatted(.number.precision(.fractionLength(2)))`. Add plural
variations for the weeks and months string.
Size: M
Decision needed: no

### 8. The calorie-floor step uses terms it does not define, and warns without saying of what
Severity: hurts usability (health and safety)
Where: `…/8 - OnboardingDiet/2 - CalorieFloor/CalorieFloorView.swift:27`;
`CalorieFloorPresenter.swift:100-111`
Guideline: "Avoid using specialized or technical terms without defining them… If you must use
such terms, be sure to define them first and make the definitions easy for people to look up."
— https://developer.apple.com/design/human-interface-guidelines/inclusion
What happens: the screen is titled "What's Your Floor?" and offers "Standard Floor
(Recommended)" and "Low Floor". "Floor" is never explained, and "TDEE" appears here without
its expansion. The low option says "never go below 800 calories per day. Proceed with caution."
with no statement of what the risk is or who the option is for. That an 800 kcal floor needs a
stronger warning is my judgment.
Fix: title "Lowest Daily Calories"; a scaffold subtitle such as "Your daily target never goes
below this, however fast your goal." Replace "TDEE" with "the calories you burn". Replace
"Proceed with caution." with a plain sentence that names the consequence and recommends
talking to a doctor first.
Size: S
Decision needed: yes — whether the 800 kcal option is offered during onboarding at all.

### 9. The wheels cannot represent some bodies, and one limit is applied silently
Severity: hurts usability (inclusion)
Where: `…/5 - Weight/WeightView.swift:64`, `:81`; `WeightPresenter.swift:38-45`;
`…/4 - Height/HeightView.swift:62`; `…/9 - Expenditure/ExpenditurePresenter.swift:83`
Guideline: "Physical attributes" is one of the human characteristics the page lists, and
"Basing design decisions on stereotypes or assumptions inevitably leads to exclusion because
generalizations can't reflect the diversity of human perspectives." —
https://developer.apple.com/design/human-interface-guidelines/inclusion
What happens: weight stops at 200 kg / 440 lb, so a heavier person has to enter a weight that
is not theirs, and every calorie figure is then built on it. Height can be set from 100 cm, but
`heightCm` clamps anything under 120 cm to 120 before the estimate, so a shorter person is
shown a number computed for someone else with no indication.
Fix: widen the weight wheel to the range the maths already accepts (`weightKg` clamps to
30…500 kg), and make the height clamp match the wheel (100 cm) rather than the reverse.
Size: S
Decision needed: no

### 10. The back button is hidden at three points, so entered data cannot be corrected
Severity: hurts usability
Where: `…/4 - CompleteAccountSetup/CompleteAccountSetupView.swift:27`;
`…/5 - HealthDisclaimer/HealthDisclaimerView.swift:39`;
`…/6 - GoalSetting/GoalSettingView.swift:29`
Guideline: "it's especially important let people swipe to navigate back" —
https://developer.apple.com/design/human-interface-guidelines/designing-for-ios
What happens: `navigationBarBackButtonHidden()` removes the button and the edge swipe. After
the profile is saved on the expenditure screen, the disclaimer blocks the way back, so a person
who notices a wrong weight on the goal screens cannot return to fix it until onboarding is
over. The earlier review counted the hidden buttons; this is what they cost in this part of the
flow. `OnboardingCompletedView.swift:42` hides it too, which is reasonable on a final screen.
Fix: remove the modifier from `HealthDisclaimerView` and `GoalSettingView`. Keep it on
`CompleteAccountSetupView` only if going back to the paywall is the concern.
Size: S
Decision needed: no

### 11. The diet questions and the Strava step are setup that could wait
Severity: hurts usability
Where: `…/8 - OnboardingDiet/` (six screens); `…/9 - StravaConnect/StravaConnectView.swift`;
`…/1 - PreferredDiet/PreferredDietPresenter.swift:16`;
`…/5 - ProteinIntake/ProteinIntakePresenter.swift:16`
Guideline: "Postpone nonessential setup flows or customization steps. Provide reasonable
default settings so most people can immediately start interacting with your app or game without
performing additional configuration." —
https://developer.apple.com/design/human-interface-guidelines/onboarding
Also "Give people a chance to engage with your app before asking for optional data." —
https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple
What happens: preferred diet, calorie floor, calorie distribution and protein level each get a
screen. Every one has an obvious default (Balanced, Standard, Even, Moderate), and the same
screens are already reachable from settings (`isFromSettings`). Only the calorie floor is
prefilled; diet and protein open with nothing selected and Continue disabled. Strava is a
third-party connection offered before the person has logged a workout.
Fix (smallest): prefill all four with the defaults so the steps are four taps. Better: replace
the four screens with one "Use recommended settings / Customize" choice, and move Strava to the
first finished workout.
Size: S for the prefill, M for the restructure
Decision needed: yes — whether diet customization and Strava stay in onboarding.

### 12. Cancelling Strava sign-in shows "Connection Failed" with a raw system error
Severity: hurts usability
Where: `…/9 - StravaConnect/StravaConnectPresenter.swift:36-38`;
`Managers/Strava/StravaManager.swift:44-45`;
also `…/9 - OnboardingCompleted/OnboardingCompletedPresenter.swift:42`;
`…/4 - GoalSummary/GoalSummaryPresenter.swift:60-63`
Guideline: "Write clear error messages… avoid blame, and be clear about what someone can do to
fix it." — https://developer.apple.com/design/human-interface-guidelines/writing
Also "Avoid using an alert merely to provide information." —
https://developer.apple.com/design/human-interface-guidelines/alerts
What happens: `authenticate()` resumes with whatever `ASWebAuthenticationSession` reports,
including the user closing the sheet. The presenter shows every error as an alert whose body is
`error.localizedDescription`. Closing the sheet is a choice, not a failure. The completion
screen shows raw errors the same way, and the goal summary's "Current weight not available."
gives no next step.
Fix: catch `ASWebAuthenticationSessionError.canceledLogin` and return silently. For real
failures use fixed copy with an action ("Strava didn't respond. Try again, or skip and connect
later in Settings."). Give the goal summary alert a route back to the weight step.
Size: S
Decision needed: no

### 13. Health data is typed in by hand, with no offer to read it from Apple Health
Severity: hurts usability
Where: steps `…/4 - CompleteAccountSetup/2 - Gender` to `5 - Weight`
(`DateOfBirthView.swift:32`, `HeightView.swift:59-103`, `WeightView.swift:61-93`)
Guideline: "With people's permission, integrate information available through platform
capabilities in ways that enhance the experience without asking people to enter data." —
https://developer.apple.com/design/human-interface-guidelines/designing-for-ios
Also "Get information from the system whenever possible. Don't ask people to enter information
that you can gather automatically… or by getting their permission" — entering-data page
What happens: date of birth, sex, height and weight are all entered on wheels. Nothing under
`Core/Onboarding/` reads Apple Health, so anyone who already keeps these there enters them
again. The onboarding Health step was removed from this tree while this review was being
written (the request now happens where Health is first used), which is the right call for the
permission and leaves this gap as it was.
Fix: give the height and weight steps one "Fill from Apple Health" button each, requesting only
that type when tapped. That is an in-context request, so it does not undo the move.
Size: M
Decision needed: yes — whether onboarding may ask for Health access at all, even on request.

### 14. The Strava button's label and two status texts fall below the contrast minimum
Severity: polish — computed, not measured
Where: `…/9 - StravaConnect/StravaConnectView.swift:37-39`, `:53`;
`…/4 - GoalSummary/GoalSummaryView.swift:91`
Guideline: "Strive to meet color contrast minimum standards" with the table "Up to 17 pts, All
weights, 4.5:1" and "All sizes, Bold, 3:1" —
https://developer.apple.com/design/human-interface-guidelines/accessibility
What happens: `CallToActionButton` draws its label in `onAccent`, which is white in the light
appearance. `.tint(Color.strava)` puts that white on system orange (255, 141, 40), about 2.3:1.
"Strava Connected" and the weight-change row are drawn as green text on a light background,
about 2:1.
Fix: keep the Strava button on the app accent and carry the brand with the glyph, or draw its
label in a dark colour. Leave status text `.primary` and let the symbol carry the colour.
Size: S
Decision needed: no

### 15. A chosen weight loss is drawn in the error colour
Severity: polish
Where: `…/4 - GoalSummary/GoalSummaryView.swift:87-91`
Guideline: "Avoid using the same color to mean different things. Use color consistently
throughout your interface, especially when you use it to help communicate information like
status" — https://developer.apple.com/design/human-interface-guidelines/color
What happens: the change row is `Color.success` for any gain and `Color.danger` for any loss,
regardless of the objective. Someone who asked to lose weight sees their own goal in the colour
the contract reserves for errors. The arrow already carries the direction.
Fix: drop the colour and keep the arrow, or colour by whether the change matches the objective.
Size: S
Decision needed: no

### 16. Copy: "we" throughout, one typo, and undefined abbreviations
Severity: polish
Where: `…/4 - CompleteAccountSetup/CompleteAccountSetupView.swift:22` ("In order to for us to
help you… we need… our recommendations"); `…/1 - NamePhoto/NamePhotoView.swift:86` ("Help us");
`…/9 - Expenditure/ExpenditureView.swift:127`, `:157-163`, `:171-173`;
`…/6 - GoalSetting/GoalSettingView.swift:22`;
`…/8 - OnboardingDiet/CustomisingDietProgramView.swift:22`, `:26`;
`…/5 - HealthDisclaimer/HealthDisclaimerPresenter.swift:69`;
`…/3 - WeightRate/WeightRatePresenter.swift:94` ("% BW");
`…/9 - OnboardingCompleted/OnboardingCompletedView.swift:21` ("Onboarding Complete!")
Guideline: "Avoid using we altogether because it may be unclear who the 'we' in question refers
to. This is particularly problematic in error messages" —
https://developer.apple.com/design/human-interface-guidelines/writing
(The inclusion page is softer: it suggests reserving "we" for the software or company.)
Also "Avoid using specialized or technical terms without defining them." — inclusion page
What happens: nine strings speak as "we". "In order to for us" has a stray word. "BMR
(Mifflin-St Jeor)", "TDEE Formula", "TDEE Result" and "% BW" are shown as labels;
"Onboarding" is the team's word for the flow, not the user's.
Fix: rewrite without "we" ("A few details tailor your recommendations."). Use "Resting
calories" and "Daily calories burned" as labels, with the abbreviation in the footer if at all.
"% of body weight". "You're all set".
Size: S
Decision needed: no

### 17. The photo control cannot undo a choice, keeps a stale label, and fails silently
Severity: polish
Where: `…/1 - NamePhoto/NamePhotoView.swift:35-46`; `NamePhotoPresenter.swift:103-112`
Guideline: "Be sure to keep your descriptions up-to-date as your app's interface and content
change." — https://developer.apple.com/design/human-interface-guidelines/voiceover
Also "Show people when a command can't be carried out and help them understand why." —
https://developer.apple.com/design/human-interface-guidelines/feedback
What happens: once a photo is picked, the button still reads "Add Photo (Optional)" to
VoiceOver, there is no way to remove the photo, and a failed or empty load is only logged.
Fix: label "Change Photo" when one is set; add a "Remove Photo" button under it; show an
`InlineMessage(.error, …)` when the load fails.
Size: S
Decision needed: no

### 18. Wheels list values from high to low, and the birth date uses the calendar style
Severity: polish — the second half is my judgment
Where: `…/4 - Height/HeightView.swift:62`, `:80`, `:90`; `…/5 - Weight/WeightView.swift:64`,
`:81`; `…/2 - TargetWeight/TargetWeightView.swift:47`, `:64`;
`…/3 - DateOfBirth/DateOfBirthView.swift:32`
Guideline: "Use predictable and logically ordered values. Before people interact with a picker,
many of its values can be hidden. It's best when people can predict what the hidden values
are" — https://developer.apple.com/design/human-interface-guidelines/pickers
What happens: every wheel is built from `.reversed()`, so scrolling down lowers the value,
the opposite of the system's own number and date wheels. The date of birth uses the default
compact style, which opens a month calendar set eighteen years back; reaching a birth year
means finding the month-and-year control inside it. The page describes the wheels style as one
that "also supports data entry through built-in or external keyboards".
Fix: remove `.reversed()`. Add `.datePickerStyle(.wheel)` to the date of birth.
Size: S
Decision needed: no

## Smaller items

- `WeightPresenter.swift:47-53` converts with `Int(_:)`, which truncates: 154 lb becomes 69 kg,
  so toggling units changes the displayed weight. `TargetWeightPresenter` already rounds.
- Weight is whole kilograms or pounds only. `Format.weight` shows one decimal everywhere else.
  My judgment.
- `DateOfBirthPresenter.swift:22-26` accepts any date up to today. `ExpenditurePresenter.swift:74`
  then treats anyone under 14 as 14 without saying so. There is no minimum age. My judgment.
- `OverarchingObjectivePresenter.swift:24` disables Continue when the stored weight is missing,
  with no message. The entering-data page asks that people "understand that they must provide
  the required data before they can proceed".
- `DietPlanView.swift:100` numbers the days "Day 1" to "Day 7" while the chart above names them
  "Mon" to "Sun". With "Vary By Day" the person needs to know which day is which.
- `OnboardingStep.orderIndex` (`UserModel.swift:542-543`) puts the training program before the
  gym profile; `inferredOnboardingStep` runs them the other way round. If those two screens
  adopt the scaffold's progress bar it will move backwards between them.
- `WeeklyMacroChart` separates its stacked segments by `Spacing.xxs` and gives each bar a
  VoiceOver label and value, which is what the charts page asks for. It has no overall
  description of what the chart shows; the page asks for one when Audio Graphs is not used.

## Contract conflicts

- **Progress bar granularity.** `CONTRACT.md` (Notes from Wave 2) says `progress` comes from
  `OnboardingStep.progress`, and the scaffold's doc comment records that the sub-screens of a
  step share one value on purpose. The result is a bar that sits at 27% for ten screens
  (account setup), 64% for five (goal setting) and 91% for six (diet), and is absent on the
  Strava and completion screens. HIG: "Be as accurate as possible when reporting advancement in
  a determinate progress indicator. Consider evening out the pace of advancement" and "People
  tend to associate a stationary indicator with a stalled process" —
  https://developer.apple.com/design/human-interface-guidelines/progress-indicators
  A fix that keeps the contract's source of truth: let a screen pass its position within the
  step, and interpolate between this step's value and the next one's.
- **`success` as a text colour.** The contract fixes `success = .green`. Used as text on a
  light background (finding 14) system green computes to about 2:1, under the 4.5:1 the
  accessibility page lists —
  https://developer.apple.com/design/human-interface-guidelines/accessibility
  The token is fine as a fill or symbol colour; the conflict is only where it colours text.

## Done well — keep

- The photo step uses `PhotosPicker`, which runs out of process, so choosing a profile photo
  needs no photo-library permission and shows no prompt. No camera access is requested.
- First and last name are prefilled from the sign-in provider, carry `textContentType`
  `.givenName` / `.familyName` and word capitalization, and the optional fields say "(optional)".
- Choices are lists of `SelectableRow`s rather than typed text, selection is announced with the
  `.isSelected` trait and a selection haptic, and subtitles explain each option without
  truncating.
- Continue is disabled until a required choice is made, as the entering-data page asks.
- The date of birth is bounded to the past, with a 120-year reach.
- Height and weight use wheels with the unit in every row, and the unit control is a two-segment
  control with noun labels.
- Save failures keep the person on the screen they were on and offer Try Again
  (`ExpenditurePresenter.swift:237-252`); the completion screen re-enables its button after a
  failed save.
- The expenditure animation goes through `withReducedMotionAnimation`, and its breakdown bars
  are each labelled in text, so colour is not the only carrier.
- The goal summary pairs the change colour with an arrow and hides the arrow from VoiceOver.
