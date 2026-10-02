# Nutrition: HIG review (2026-09-28)

Reviewed against the live HIG with the `apple-hig` skill, `--platform ios`.

**Pages read:** `designing-for-ios`, `entering-data`, `text-fields`, `virtual-keyboards`,
`pickers`, `steppers`, `lists-and-tables`, `searching`, `search-fields`, `sheets`, `modality`,
`alerts`, `loading`, `progress-indicators`, `privacy`, `generative-ai`, `machine-learning`,
`healthkit`, `feedback`, `accessibility`, `writing`, `images`, plus `toolbars`, `buttons`,
`segmented-controls`, `action-sheets`, `voiceover` and `materials` where the code needed them.

**Scope.** All of `Core/Nutrition/` (145 files; every view and the presenters behind them), the
shared number field it depends on (`Components/Views/TextFields/AutoSelectNumberField.swift`,
`Components/DesignSystem/NumberField.swift`, `Extensions/Double+EXT.swift`), the camera and photo
request sites, and the purpose strings in `project.pbxproj`.
`Components/Views/Nutrition/` and `Components/Views/MealItemLabel/` no longer exist: both now
live under `Core/Nutrition/Components/` and were read there.

**Not reviewed.** Food Log settings (`Core/Profile/...`), the calendar header, the Cloud
Functions prompts. **AI chat and AI image generation have no screen**: `generateText` and
`generateImage` exist on `AIManager` and `CreateFoodInteractor` but nothing in `Core/` calls
them, so there was nothing to review. No nutrition screen requests Apple Health access, so the
`healthkit` page produced no findings here.

**Not checked.** This is a code review. Nothing was built or run, so Dark Mode, the largest text
sizes, VoiceOver, iPad and Mac Catalyst are all unverified. Where a finding depends on runtime
behaviour it says so.

Paths are relative to `DialedIn/`. Findings are most serious first.

## Decisions built (2026-09-29, branch hig/nutrition)

| Decision | Status | What changed |
|---|---|---|
| 9a | built | Every add path now plays a success haptic and returns to the list instead of staying put or silently duplicating: the amount screens (`IngredientAmountView`, `RecipeAmountView`, `MealItemAmountViewView`) rename "Log" to "Add" and pop back to the caller on confirm; `FoodLibraryPickerRowView` gained an `addedCount` badge that turns the "+" into a checkmark-and-count once a food is on the plate, wired through search and the library's Foods tab; the picker's toolbar shows "N on plate" beside Close. Also fixed, as its own `[Fix]` commit: the barcode scanner's "Use This Food" called `dismissScreen()` on the picker's shared router after handing the food back, closing the whole picker before the amount screen could show. |
| 9b | built | The photo scanner and Describe both disclose that the input is sent to Google's AI service for analysis and isn't stored by Compound, with the exact wording from the decision. Both results sections are retitled "AI Estimate" with the "Estimates can be wrong" footer, and a result now opens the amount screen prefilled (via a new `FoodAnalysisItem.estimatedFood`) instead of adding directly. The Describe footer became the "2 eggs and a slice of toast" example; both screens show a "No Foods Recognized" empty state instead of nothing. |
| 9c | built | The Food Packaging step and "Share New Foods Publicly" toggle are hidden from `CreateFoodView`; `CreateFoodPresenter.onNextPressed` always takes the portion-definition route since the toggle can no longer be turned on. Both sites carry a `// TODO:` for when the public database contribution ships. The setting doesn't exist anywhere under `Core/Profile/Subviews/NutritionSettings/`, so no change was needed there. |
| 13g | built | `RecipeDetailView`'s "Start" toolbar button — a wide `.glassProminent` button with a text label — was what crowded the title bar; Food detail and Workout template detail don't carry an equivalent action in their toolbars. Moved Start into a `.bottomCTA`, the way Workout template detail presents its own primary action, leaving the toolbar with only Close, the dev-info button, the heart and the delete menu. The full title now fits. |
| 7b | built | `NutritionPresenter.onViewAppear` calls `ReminderOfferFlow.offerMealRemindersIfNeeded()` in place of the deleted `scheduleMealRemindersIfNeeded()` private method and its `hasMealRemindersScheduled` flag. `NutritionInteractor` now inherits `ReminderOfferInteractor`. `ReminderOfferFlow.swift` itself was not touched. |

## Resolution (2026-09-28, branch hig/nutrition)

| # | Status | What changed |
|---|---|---|
| 1 | fixed | Parsing was already fixed on `feature/hig` (`Double.typed`); no `Double(text)` parse site remains in `Core/Nutrition/`. Prefilled amounts now use the region's format instead of `%g`. |
| 2 | fixed | Editing a timeline item writes the new item into its meal and saves it; a failure alerts. Tested. |
| 3 | fixed | Opened from Create Food, the scanner returns the scanned or typed barcode and closes, with no lookup; it has a title and Close there and hides the label mode. Tested. |
| 4 | fixed | Camera permission is read and requested at the moment of use; "Camera Access Is Off" with Open Settings (and Enter Manually on the scanner) is separate from "not supported". Tested. |
| 5 | skipped: decision | |
| 6 | skipped: decision | |
| 7 | fixed | Each nutrient field shows its stored unit, kJ is converted to kcal, the two placeholder segments are removed, Create needs energy. Tested. |
| 8 | skipped: decision | |
| 9 | fixed in part | Close added to Food detail, Recipe detail, Ingredient list, Timeline Actions and the standalone scanner; the picker's Done became Close; the meal time sheet has Cancel. Not done: flattening the four-deep modal stack (size L; needs routing changes across the picker). |
| 10 | fixed | Create Food and Create Recipe confirm before discarding entered data; the swipe is blocked while there is something to lose. |
| 11 | fixed | `isSaving` guard and `CallToActionButton(isLoading:)` on Add Meal, Create Food, Create Recipe, Quick Add Log and Copy Day; Clear Day is disabled while working. Tested. |
| 12 | fixed | Every listed site now names the failed action; offline keeps the offline alert (`GlobalRouter.showFailure`); search says when it is offline. |
| 13 | fixed | "Add Meal" title, Add Food row in Your Plate, calorie readout and thumbnails removed from the bar; accessory reads "Unlogged meal" with count and calories. |
| 14 | needs a change elsewhere | The purpose string lives in `project.pbxproj`, which this branch does not own. |
| 15 | fixed | Next is disabled until name and servings are filled in; the alert is gone; ingredients can be deleted. Tested. |
| 16 | fixed | Confirmation dialog "You have an unlogged meal" / "Continue Meal" / "Discard and Start New". The copies in Dashboard, Search, Energy Balance and Analytics are outside this branch. |
| 17 | fixed | All five hints use `.primary`; "Label text captured" sits on the same glass capsule. |
| 18 | fixed | Text-only segmented control, title-case buttons and alert titles, "flashlight", "Favorites", localized mode and unit names, "kJ", toggle renamed with a footer instead of the Learn More alert, ellipses. |
| 19 | fixed in part | Edit and Quick add labels name the item; a timeline row opens Meal detail on tap and from a context menu. Not done: a visible alternative to the hour chip's long press when "Show Add Foods Button" is off (needs an Add Meal route from Timeline Actions). |
| 20 | not done | Needs an AX3 run first, as the finding says; no simulator was used on this branch. |
| Smaller | fixed in part | Photo scanner explains an offline capture; Food detail no longer shows the author id; a failed favorite toggle alerts; library rows without a picture show the neutral placeholder. Not done: Check-in CTA layout, Meal Time sheet as a compact picker (conflicts with keeping the time in the bar, finding 13), Recipe detail's Start screen. |
| Foundations | fixed where owned | Context menus mirror the timeline and plate swipe actions; Food detail nutrient labels and meal summary labels are localized; food and recipe hero images are hidden from VoiceOver. |

## Findings

### 1. Decimal amounts cannot be typed where the decimal separator is a comma
Severity: blocks people
Where: `Extensions/Double+EXT.swift:50-51`, `Components/Views/TextFields/AutoSelectNumberField.swift:43`,
`Core/Nutrition/MealLog/IngredientAmount/IngredientAmountView.swift:25-26`,
`Core/Nutrition/MealLog/MealItemAmountView/MealItemAmountViewView.swift:24-27`, `:111-112`,
`Core/Nutrition/MealLog/RecipeAmount/RecipeAmountView.swift:23-24`,
`Core/Nutrition/Recipes/CreateRecipe/RecipeIngredientAmount/RecipeIngredientAmountView.swift:16-17`
Guideline: "Use a number formatter to help with numeric data… Don't assume the actual
presentation of data, however, as formatting can vary significantly based on people's locale." —
https://developer.apple.com/design/human-interface-guidelines/text-fields
What happens: every amount field is a text field parsed with `Double(text)`, which only accepts
"." as the separator, behind a `.decimalPad` keyboard, which offers the region's separator. In
Spain (the app ships a complete Spanish translation) the pad offers ",", so "1,5" parses to 0 and
Log stays disabled; in `NumberField` the value is cleared instead. Whole numbers still work.
Prefilled values are written with `String(format: "%g")`, so they also show "." in a "," region.
Not run; the keyboard behaviour is UIKit's documented one.
Fix: bind the number, not the string. `CreateRecipeView.swift:83` already does it correctly:
```swift
TextField("Amount", value: $presenter.amount, format: .number)
    .keyboardType(.decimalPad)
```
In `AutoSelectNumberField` parse and print through the same `FormatStyle`
(`try? Double(newValue, format: .number)` and `value.formatted(.number)`), which fixes every
`NumberField` in the app at once. Then move the four amount screens onto `NumberField`.
Size: M
Decision needed: no

### 2. Editing a logged item from the timeline saves nothing, and plays the success haptic
Severity: blocks people
Where: `Core/Nutrition/NutritionPresenter.swift:250-258`,
`Core/Nutrition/MealLog/MealItemAmountView/MealItemAmountViewPresenter.swift:69-91`,
`Core/Nutrition/NutritionView.swift:120-122`
Guideline: "Show people when a command can't be carried out and help them understand why." —
https://developer.apple.com/design/human-interface-guidelines/feedback
What happens: the pencil on every timeline row opens the amount screen with
`onConfirm: { _ in }`. Save plays `.success`, closes the screen, and the meal is unchanged.
`MealDetailView` is read-only by design, so a logged item cannot be corrected anywhere; the only
route is delete and log again.
Fix: pass the meal into `onEditMealItem`, replace the item in a copy of it and save through
`interactor.addMeal(updatedMeal)`, the call `deleteMealItem` already uses at `:223`. Add a
presenter test that the saved meal carries the new amount.
Size: S
Decision needed: no

### 3. Create Food's "Scan Barcode" can never return a barcode
Severity: blocks people
Where: `Core/Nutrition/Foods/CreateFood/CreateFoodPresenter.swift:119-128`,
`Core/Nutrition/Foods/CreateFood/CreateFoodView.swift:140-161`,
`Core/Nutrition/MealLog/NutritionLibraryPicker/BarcodeScanner/BarcodeScannerView.swift:6`,
`:287-306`, `:425-429`
Guideline: "Show people when a command can't be carried out and help them understand why." —
https://developer.apple.com/design/human-interface-guidelines/feedback ; "Always give people an
obvious way to dismiss a modal view… people typically expect to find a button in the top toolbar
or swipe down" — https://developer.apple.com/design/human-interface-guidelines/modality
What happens: Create Food passes `onBarcodeScanned`, but the scanner never calls it (the only
callers are in the unit tests). The scanner runs a product lookup instead. If the product exists,
"Use This Food" calls the nil `onFoodFound` and closes; if it does not exist, which is the usual
reason to create a food, the card shows an error with only "Re-scan". Either way the barcode row
stays empty. Opened this way the scanner is a sheet with no title and no Close button.
Fix: when the delegate has `onBarcodeScanned`, skip the lookup: on detection (and on manual
entry) call it with the code and dismiss. Give the standalone scanner a `navigationTitle` and a
`Button(role: .close)` in `.cancellationAction`.
Size: M
Decision needed: no

### 4. With camera access denied the scanner says the device is unsupported, and the fallback is hidden
Severity: blocks people
Where: `…/BarcodeScanner/BarcodeScannerView.swift:19`, `:48-54`, `:128-135`;
`…/FoodPhotoScanner/FoodPhotoScannerView.swift:37`, `:49-55`, `:143-152`
Guideline: "If you need to direct someone to a setting, provide a direct link or button, rather
than trying to describe its location." — https://developer.apple.com/design/human-interface-guidelines/writing ;
"Show people when a command can't be carried out and help them understand why." — feedback page
What happens: `DataScannerViewController.isAvailable` is false whenever camera access is not
granted or is restricted, and the view then shows "Scanner Unavailable. Scanner not supported on
this device." The keyboard button that opens manual entry is inside the branch that needs the
camera, so the one path that works without a camera cannot be reached. The photo scanner checks
only `isSourceTypeAvailable(.camera)`, which stays true after a denial, so it shows a capture
button over a black preview with no explanation. There is no `AVCaptureDevice` authorization
check anywhere in the app.
Unverified: whether `isAvailable` is already false before the first prompt. If it is, nobody
ever reaches the system alert on the Barcode tab. Check this on a fresh install first.
Fix: read `AVCaptureDevice.authorizationStatus(for: .video)`. `.notDetermined`: call
`requestAccess` when the Barcode or AI chip is tapped (that is the moment of use, so no pre-alert
screen is needed). `.denied`/`.restricted`: `ContentUnavailableView` titled "Camera Access Is
Off", a description, and two actions: "Open Settings" (`UIApplication.openSettingsURLString`)
and "Enter Manually". Keep "not supported" for `isSupported == false` only.
Size: M
Decision needed: no

### 5. Adding a food gives no sign that it was added
Severity: hurts usability
Where: screen stays put after Log: `…/IngredientAmount/IngredientAmountPresenter.swift:55-58`,
`…/RecipeAmount/RecipeAmountPresenter.swift:50-69`. Added silently, no haptic and no change on
screen: `…/FoodPhotoScanner/FoodPhotoScannerView.swift:85-87`,
`…/MealDescribe/MealDescribePresenter.swift:64-83`,
`Components/IngredientListBuilder/IngredientListBuilderPresenter.swift:78-99`,
`…/NutritionLibraryPickerPresenter.swift:38-41`, `…/FoodLibrary/FoodLibraryPresenter.swift:56-59`.
Closes the picker: `…/BarcodeScanner/BarcodeScannerView.swift:296-299`
Guideline: "Feedback helps people know what's happening, discover what they can do next,
understand the results of actions, and avoid mistakes." —
https://developer.apple.com/design/human-interface-guidelines/feedback ; "Build language
patterns. Consistency builds familiarity" — https://developer.apple.com/design/human-interface-guidelines/writing
What happens: the picker is a sheet over the plate, so the plate is not visible while picking.
On the amount screens "Log" plays a haptic and appends the item, but nothing dismisses or
changes, so a second tap adds a second copy. The AI result rows, the "+" quick-add buttons and
Quick Add mode append with no haptic and no visual change at all. `MealItemAmountViewPresenter`
does dismiss, so the same step behaves two ways. "Log" here means "add to plate"; the meal is
logged only by "Log" on Add Meal, and Quick Add already words the two correctly ("Add to Plate"
and "Log").
Also, from code reading and worth a run: "Use This Food" pushes the amount screen and then calls
`dismissScreen()` on the picker's own router, which `GlobalRouter.swift:25` documents as "this
screen and all screens in front of it", so with Quick Add off the picker closes before an amount
can be entered.
Fix: one rule for every add path: `playHaptic(.success)`, then either pop back to the list
(amount screens) or mark the row (swap the "+" for a checkmark with a count, and show "3 on
plate" beside Done in the picker toolbar). Rename the amount screens' button "Add". In the
scanner, do not dismiss after `onFoodFound`.
Size: M
Decision needed: yes — after adding from an amount screen, return to the list or to the plate?

### 6. The AI features do not say they are AI, that data leaves the device, or that results are estimates
Severity: hurts usability (trust), App Review exposure
Where: `…/MealDescribe/MealDescribeView.swift:17-51`,
`…/FoodPhotoScanner/FoodPhotoScannerView.swift:59-100`,
`…/BarcodeScanner/BarcodeScannerView.swift:179-221`, `:234-285`,
`Core/Nutrition/Components/Shared/FoodAnalysisResultRow.swift:15-35`,
`…/NutritionLibraryPickerPresenter.swift:71-79`
Guideline: "Communicate where your app uses AI." and "Be transparent by making sure people know
their information may be sent to a server, showing them what's shared" and "it's important to
clearly communicate that AI-generated content may contain errors" and "Make it easy for people
to refine or revert generated results… surfacing controls like Edit, Undo, Retry, or Adjust near
generated content" — https://developer.apple.com/design/human-interface-guidelines/generative-ai
What happens: the photo, the typed description and the scanned label text go to a Cloud
Function running a Vertex AI model. The only mention of AI is a chip titled "AI" with a camera
icon; "Describe" and label parsing never mention it. Results appear under "Results" as plain
figures (calories to the unit, grams to a decimal) with no sign that they are estimates. A
result can only be added as is: the amount is editable later, from the plate, not where the
estimate is shown. If the model returns no items, Describe shows nothing at all after the
spinner and the photo scanner shows an empty "Results" section. The Describe footer is "Common
foods only", which does not say what to type.
Fix: (a) one line under each AI input, for example "Estimated by AI from your photo. The photo
is sent to our server for analysis and is not stored." Say only what is true of the backend.
(b) Title the sections "AI Estimate" and add a footer "Estimates can be wrong. Check amounts
before logging." (c) Make a result row open the amount screen, prefilled, instead of adding
directly. (d) Empty result: `ContentUnavailableView` with "No foods recognized" and a hint
("Try naming each food and its amount, such as '2 eggs and a slice of toast'"). (e) Replace the
footer with that same example.
Size: M
Decision needed: yes — the disclosure wording, and whether photos and text are retained server
side (the copy must match `docs/AppPrivacy.md`)

### 7. Create Food's nutrition form shows units it does not use, and two of its three modes are placeholders
Severity: hurts usability (wrong data is stored)
Where: `Core/Nutrition/Foods/CreateFood/FoodDefinition/FoodDefinitionView.swift:79-95`,
`:105-118`, `:169-183`; `FoodDefinitionPresenter.swift:12-13`, `:175-225`
Guideline: "Be clear about the data you need." and "make sure people understand that they must
provide the required data before they can proceed" —
https://developer.apple.com/design/human-interface-guidelines/entering-data
What happens: every nutrient field is labelled with the one shared weight unit, "g" or "oz",
including sodium, the vitamins and caffeine. The values are stored unconverted under keys that
mean milligrams or micrograms (`.sodiumMg`, `.vitaminB12Mcg`), so 0.4 typed as grams of sodium
is saved as 0.4 mg. The kcal/kJ picker and the g/oz picker change the label only; nothing
converts (Quick Add does convert, `FoodItemQuickAddPresenter.swift:40-43`). The segmented
control offers "US Label" and "Non-US Label", which each show one line of text and nothing to
fill in, while Create stays enabled. Create is also enabled with every field empty.
Fix: give each `Row` its own unit from `NutrientKey.unit` and show that; drop the per-row unit
picker or convert on save; convert kJ to kcal on save. Remove the two unfinished segments until
they exist. Disable Create until Energy has a value.
Size: M
Decision needed: no

### 8. The Food Packaging step looks interactive where it is not, and drops the photos
Severity: hurts usability
Where: `Core/Nutrition/Foods/CreateFood/FoodPackaging/FoodPackagingView.swift:43-69`, `:75-79`,
`:97-98`, `:101-107`; `FoodPackagingPresenter.swift:11-16`, `:42-49`
Guideline: "Ensure that each button clearly communicates its purpose." —
https://developer.apple.com/design/human-interface-guidelines/buttons ; feedback page, as in
finding 5
What happens: the two photo buttons show a camera symbol and open the photo library. Choosing a
photo changes nothing on screen, and nothing loads the chosen item into
`selectedFrontImageData`, so Next always passes `nil` for both photos. "Don't ask for product
images again" is drawn with a checkmark circle but is plain text. "Open Food Facts" is
underlined like a link and is not one.
Fix: load each `PhotosPickerItem` in `onChange` (as `CreateFoodView.swift:56-62` does) and show
the chosen photo in the button. Use the photo symbol, or offer the camera as well. Make the
footer a real `Toggle` backed by a setting or remove it. Make the underline a `Link` or remove it.
Size: M
Decision needed: yes — is the public-database contribution shipping? If not, hide the toggle on
Create Food and this whole step

### 9. Modal screens stack up to four deep, and several have no Close button
Severity: hurts usability
Where: stack: `AddMealView.swift:344` (full-screen cover) → `NutritionLibraryPickerView.swift:130`
(sheet) → `CreateFoodView.swift:211` (sheet) → `BarcodeScannerView.swift:426` (sheet). Also from
the picker: `RecipeDetailView.swift:144` (sheet), `CreateRecipeView.swift:157` (cover).
No Close button: `FoodDetailView.swift:176-213`, `RecipeDetailView.swift:83-130`,
`IngredientListBuilderView.swift:86-97`, `TimelineActionsView.swift:45`,
`BarcodeScannerView.swift` (standalone). Done with no Cancel:
`NutritionLibraryPickerView.swift:68-76`, `AddMealView.swift:75-79`
Guideline: "Display only one sheet at a time from the main interface… If closing a sheet takes
people back to another sheet, they can lose track of where they are in your app." and "Provide
an alternative to the Done button." — https://developer.apple.com/design/human-interface-guidelines/sheets ;
"if you use a swipe gesture to dismiss a view, also make a button available" —
https://developer.apple.com/design/human-interface-guidelines/accessibility
What happens: creating a food with a barcode while logging a meal puts four modal layers on
screen, each closing onto the one below. Five sheets can only be closed by swiping down.
Fix: inside the picker, push Create Food and the detail screens on the picker's own stack
instead of presenting them; present the scanner from Create Food as a cover that replaces, not
stacks. Add `Button(role: .close)` in `.cancellationAction` to the five sheets (the contract's
Dismiss pattern). In the picker, where picks apply immediately, a Close button is the honest
one; keep Done only if finding 5 adds a count beside it.
Size: L
Decision needed: no

### 10. Closing a create flow throws the form away without asking
Severity: hurts usability
Where: `Core/Nutrition/Foods/CreateFood/CreateFoodPresenter.swift:71-73`,
`Core/Nutrition/Recipes/CreateRecipe/CreateRecipePresenter.swift:49-51`; no
`interactiveDismissDisabled` anywhere under `Core/Nutrition/`
Guideline: "If people have unsaved changes in the sheet when they begin swiping to dismiss it,
use an action sheet to let them confirm their action." — sheets page; "help people avoid data
loss by getting confirmation before closing a modal view" —
https://developer.apple.com/design/human-interface-guidelines/modality
What happens: Create Food is a sheet with up to four pushed steps and about sixty fields. A
swipe down or a tap on Close at any step discards all of it. Create Recipe loses its ingredient
list the same way.
Fix: when anything has been entered, `.interactiveDismissDisabled(true)` and route both Close
and the swipe to `router.showConfirmationDialog` with "Discard Food" (destructive) and "Keep
Editing".
Size: M
Decision needed: no

### 11. Saving shows no progress and the button stays live
Severity: hurts usability
Where: `AddMealView.swift:47-54`, `FoodDefinitionView.swift:105-118`,
`RecipePreparationView.swift:61-85`, `FoodItemQuickAddView.swift:41-46`,
`TimelineActionsView.swift:69-75`, `TimelineActionsPresenter.swift:51`, `:124` (Copy Day, Clear Day)
Guideline: "Configure a button to display an activity indicator when you need to provide
feedback about an action that doesn't instantly complete." —
https://developer.apple.com/design/human-interface-guidelines/buttons
What happens: each of these awaits a remote write, two of them with an image upload, and the
screen does not change until it returns. A second tap starts a second save, which for Create
Food, Create Recipe, Log and Copy Day means a duplicate. `CallToActionButton(isLoading:)`
exists and is used once in the area (`MealDescribeView.swift:60`).
Fix: an `isSaving` flag on each presenter, set around the `Task`, passed to `isLoading:` and
guarded at the top of the method. `CheckInPresenter` already does this.
Size: M
Decision needed: no

### 12. People are shown raw error text
Severity: hurts usability
Where: inline: `BarcodeScannerPresenter.swift:112`, `:132`, `:185`;
`MealDescribePresenter.swift:57`; `FoodPhotoScannerPresenter.swift:57`. Alert body:
`RecipePreparationPresenter.swift:69`, `:111`. Alert titled "Error" with the raw text
(`Root/RIBs/GlobalRouter.swift:40`): `NutritionPresenter.swift:227`, `:244`;
`NutritionOverviewPresenter.swift:100`, `:129`; `CheckInPresenter.swift:272`, `:357`. 13 sites
Guideline: "Write clear error messages… be clear about what someone can do to fix it." —
writing page; "Avoid writing a title that doesn't convey useful information — like 'Error'" —
https://developer.apple.com/design/human-interface-guidelines/alerts
What happens: `error.localizedDescription` from a JSON decode or a Cloud Function reads like
"The data couldn't be read because it isn't in the correct format." or "INTERNAL". It names no
cause a person can act on, and it is not translated.
Fix: map to a sentence per action, as `FoodItemSearchView.swift:56` and `AddMealPresenter.swift:109-112`
already do: "Couldn't read this label. Hold the camera steady and try again, or enter it
manually." Keep the raw error in analytics only. In `FoodItemSearchPresenter.swift:65-69` the
offline case should say so ("You're offline. Showing your library only.").
Size: M
Decision needed: no

### 13. Add Meal has no title and a crowded toolbar; the draft bar says "Elapsed"
Severity: hurts usability
Where: `Core/Nutrition/MealLog/AddMeal/AddMealView.swift:31`, `:243-289`, `:308-322`;
`Core/Nutrition/Components/MealAccessory/MealAccessoryView.swift:51-77`, `:86-96`
Guideline: "Make it easy to identify a modal view's task… provide a title that names the modal
view's task" — modality page; "Make sure the meaning of each control is clear. Don't make people
guess or experiment to figure out what a toolbar item does." and "Choose items deliberately to
avoid overcrowding." — https://developer.apple.com/design/human-interface-guidelines/toolbars
What happens: the screen sets no `navigationTitle`. Its top bar holds Close, a two-line
time/date button, a "0/2000" readout, a plate icon with up to five thumbnails, and a
`chevron.up` button that opens the food picker. Once the plate has an item that chevron is the
only way to add another. The thumbnails all load the "SplashScreen" asset rather than the
food. The tab bar's draft accessory reuses the workout one: it reads "Elapsed: 12:04" and draws
a checkmark over every thumbnail, and never says it is an unlogged meal.
Fix: `navigationTitle("Add Meal")`. Move "Add Food" into the list as the last row of Your
Plate (`ListRowButton` with `Symbol.add`). Move the calorie readout into the Nutrition section
it duplicates, and drop the thumbnails. Keep Close and the time button in the bar. Accessory:
title "Unlogged meal", subtitle "3 items · 640 kcal".
Size: M
Decision needed: no

### 14. The camera purpose string is passive and does not say where the photo goes
Severity: hurts usability (trust), App Review exposure
Where: `DialedIn.xcodeproj/project.pbxproj:1016`, `:1365`, `:1447`
Guideline: "Aim for a brief, complete sentence that's straightforward, specific, and easy to
understand. Use sentence case, avoid passive voice, and include a period at the end." —
https://developer.apple.com/design/human-interface-guidelines/privacy
What happens: the string is "Your camera may be used to add media to the app for barcode
scanning, food recognition etc." It is passive, ends in "etc." and omits progress photos, which
use the same permission.
Fix: "Compound uses the camera to scan barcodes and nutrition labels, to photograph meals for
analysis, and to take progress photos." Update all three build configurations together.
Size: S
Decision needed: no

### 15. Create Recipe's Next button is always enabled and objects afterwards
Severity: polish
Where: `Core/Nutrition/Recipes/CreateRecipe/CreateRecipeView.swift:29-35`, `:42-48`, `:78-96`;
`CreateRecipePresenter.swift:37-39`, `:59-66`
Guideline: "if you include a Next or Continue button after a set of text fields, make the
button available only after people enter the data you require." — entering-data page
What happens: two fields are marked Required. Next with no serving quantity raises an alert;
Next with no name proceeds and saves a recipe with an empty name, because `canSave` is never
read. An ingredient, once added, cannot be removed from the list.
Fix: `.disabled(!presenter.canSave)` with `canSave` covering both fields, and delete the alert.
Add `.onDelete` to the ingredient rows.
Size: S
Decision needed: no

### 16. The draft-meal prompt is an alert offering three choices
Severity: polish
Where: `Core/Nutrition/Components/MealHourHeader/MealHourHeaderPresenter.swift:62-91`. The
same block is copied in Dashboard, Search, Energy Balance and two Analytics presenters (outside
this review)
Guideline: "Use an action sheet — not an alert — to offer choices related to an intentional
action." and "Write a title that clearly and succinctly describes the situation." —
https://developer.apple.com/design/human-interface-guidelines/alerts
What happens: tapping Add with a draft open shows "Unable to add new meal / You already have a
draft meal." with "Continue editing", "Delete drafted meal" and Cancel. Nothing failed; the
title reports an error for what is a choice.
Fix: `router.showConfirmationDialog`, title "You have an unlogged meal", actions "Continue
Meal", "Discard and Start New" (destructive), Cancel. Better: open the draft directly and let
Add Meal offer "Discard".
Size: S here, M with the copies
Decision needed: no

### 17. Status text over the live camera has no backing, or is secondary colour on glass
Severity: polish
Where: `…/BarcodeScanner/BarcodeScannerView.swift:195-197` (no background), `:158-160`,
`:167-169`, `:184-186`, `:212-214`
Guideline: "Strive to meet color contrast minimum standards… it's important that there's
enough contrast between foreground text and icons and background colors." — accessibility page
What happens: "Label text captured" is caption-size secondary text drawn straight onto the
camera feed. The four hints sit on a glass capsule but use `.secondary`, the lowest-contrast
label colour, over whatever the camera sees. Not run.
Fix: `.foregroundStyle(.primary)` for all five, and put "Label text captured" in the same
capsule as the others.
Size: S
Decision needed: no

### 18. Wording and control details that differ from screen to screen
Severity: polish
Where and guideline:
- Segmented control mixes two text segments and a heart image,
  `…/FoodLibrary/FoodLibraryView.swift:99-104`, `:136-142`. "Prefer using either text or
  images — not a mix of both — in a single segmented control." —
  https://developer.apple.com/design/human-interface-guidelines/segmented-controls . Use
  "Favorites".
- Button titles in sentence case: "Log weight", "End my break", "Stay on a break", "Start a
  break", "No thanks", "Not now" (`CheckIn/CheckInView.swift:91-171`), "Skip this week"
  (`NutritionOverviewView.swift:49`), "Continue editing". Elsewhere they are title case ("Add
  to Plate", "Use This Food"). "Using title-style capitalization" — buttons page. Alert titles
  are split the same way: "Unable to Save Meal" against "Unable to log food", "Nothing to copy".
  "Adopt capitalization rules… then apply them consistently." — writing page.
- "Turn on torch" (`BarcodeScannerView.swift:145`) and the "Favourites" accessibility label
  (`FoodLibraryView.swift:140`) are British; README decision 8 is US spelling ("flashlight",
  "Favorites").
- Scanner mode titles come from `mode.rawValue.capitalized` (`BarcodeScannerView.swift:120`) and
  unit names "grams", "ounces", "milliliters" are literals
  (`FoodItemQuickAddView.swift:69-70`, `:90`), so none of them is translated. "kj" should be
  "kJ" (`:119`).
- "Submit Foods to the Public Database?" with the subtitle "Toggle this option to contribute
  new foods" (`CreateFoodView.swift:165-169`). "Describe what it does when turned on" — writing
  page. Use "Share New Foods Publicly" and move the Learn More text into the section footer
  instead of an alert (`CreateFoodPresenter.swift:107-117`; "Avoid using an alert merely to
  provide information." — alerts page).
- Three periods instead of an ellipsis character in four progress labels
  (`BarcodeScannerView.swift:158`, `:184`, `FoodPhotoScannerView.swift:62`,
  `FoodItemSearchView.swift:51`). My judgment; the pages read do not rule on it.
Size: M in total, each S
Decision needed: no

### 19. Repeated VoiceOver labels, and two actions reachable only by gesture
Severity: polish
Where: `Components/MealItemLabel/MealItemLabel.swift:45` and `AddMealView.swift:122` ("Edit
meal item" on every row), `Components/FoodLibraryPickerRow/FoodLibraryPickerRowView.swift:84`
("Quick add" on every row); `NutritionView.swift:131-137`;
`Components/MealHourHeader/MealHourHeaderView.swift:25-32`
Guideline: "System-provided controls have generic labels by default, but you should provide
more descriptive labels that convey your app's functionality." —
https://developer.apple.com/design/human-interface-guidelines/voiceover ; "Offer alternatives
to gestures. Make sure your UI's core functionality is accessible through more than one type of
physical interaction." — accessibility page
What happens: a list of twenty foods reads "Quick add, button" twenty times. Meal detail, which
holds Delete Meal, opens only from a leading swipe on a row. With "Show Add Foods Button" off,
adding a meal from the timeline is a long press on the hour chip; VoiceOver gets a named action
for it, other people get no visible control.
Fix: `.accessibilityLabel("Edit \(item.displayName)")` and `"Quick add \(name)"`. Make the
timeline row itself a button that opens Meal detail. Keep the long press as a shortcut and
leave the "+" visible, or add "Add Meal" to the Timeline Actions sheet.
Size: S
Decision needed: no

### 20. Four figures in a row are unlikely to survive the largest text sizes
Severity: polish — **unverified, my judgment**
Where: `Components/MacroHeader/MacroHeader.swift:85-96`, `:131-139`;
`MealItemAmountViewView.swift:93-102`; `MealDetailView.swift:41-46`;
`Components/MealHourHeader/MealHourHeaderView.swift:47-57`; `AddMealView.swift:256-262`
(two-line label in the top bar)
Guideline: "Support larger text sizes… Ideally, give people the option to enlarge text by at
least 200 percent" — accessibility page
What happens: each site puts four values side by side in a fixed `HStack`. `MacroHeader` caps
its text at one line with a 0.75 scale factor, so at accessibility sizes it shrinks and then
truncates rather than growing.
Fix: run these five at AX3 first. Where they fail, switch to a 2×2 grid with
`ViewThatFits` or `dynamicTypeSize.isAccessibilitySize`.
Size: M
Decision needed: no

## Smaller items

- Check-in (`CheckIn/CheckInView.swift`): the step's main action and its alternative are two
  identical plain rows ("Accept" / "Not now", "Log weight" / "Skip"), and there is no way back
  to an earlier step. The contract's `.bottomCTA` with one `CallToActionButton` fits here.
- Meal Time sheet (`AddMealView.swift:58-83`): a graphical date-and-time picker in a
  non-scrolling `VStack` at the medium detent. A compact `DatePicker` in the list would avoid
  the sheet ("Avoid switching views to show a picker." — pickers page). It also accepts future
  dates.
- Photo scanner offline (`FoodPhotoScannerPresenter.swift:38-39`): the guard returns after the
  photo is already shown, leaving an empty "Results" section under the offline alert.
- Recipe detail's prominent "Start" (`RecipeDetailView.swift:105-113`) opens a screen that lists
  the same ingredients and nothing else (`RecipeStartView.swift:16-27`).
- Food detail prints the author's raw user id under "Author ID" (`FoodDetailView.swift:168-174`).
- A failed favourite toggle reverts the heart with no message
  (`FoodDetailPresenter.swift:46-49`, `RecipeDetailPresenter.swift:47-49`).
- A food with no picture shows the "SplashScreen" asset in library rows
  (`FoodLibraryPickerRowView.swift:93`). A neutral symbol, as `MealItemLabel` uses, reads better.

## Contract conflicts

None that is flat. One tension to be aware of: the contract makes `.glass` the secondary button
style, and nutrition uses it for per-row Edit and "+" buttons inside lists. The HIG says "Use
Liquid Glass effects sparingly… Limit these effects to the most important functional elements in
your app." — https://developer.apple.com/design/human-interface-guidelines/materials . A list of
twenty rows draws twenty glass circles. This is the contract's call; it is recorded here, not
reported as a finding.

## Done well — keep

- The picker opens on Search, so the camera starts only when someone chooses Barcode or AI.
- Photo library access goes through `PhotosPicker` everywhere, so no library permission is
  requested at all.
- The scanner offers manual entry for both barcode and label, prefilled with what the camera
  caught, with the number pad for barcodes.
- The plate autosaves as a draft, so closing Add Meal loses nothing.
- Search tells a failed request apart from no results, debounces, and drops superseded answers.
- Macros never rely on colour alone: `MacroChips` and `MacroHeader` pair each colour with a
  symbol or letter and give VoiceOver the macro's name.
- Absent nutrients are left out or shown as a dash rather than as zero.
- Destructive actions that cannot be undone (Clear Day, Delete Meal, Delete Food) confirm with
  a named destructive button and Cancel; per-item swipe delete does not nag.
- Empty states use `ContentUnavailableView` with an action (`AddMealView.swift:88-97`,
  `IngredientListBuilderView.swift:67-73`).
- The scanner's slide-in honours Reduce Motion (`BarcodeScannerView.swift:45`).
