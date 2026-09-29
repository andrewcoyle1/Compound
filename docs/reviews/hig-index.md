# HIG findings index

Generated from the nine area reviews and their Resolution tables. Last generated 2026-09-29.

| Status | Findings |
|---|---|
| fixed | 85 |
| waiting on a decision | 43 |
| needs a change elsewhere | 18 |
| fixed in part | 13 |
| needs a package change | 1 |
| already fixed / not a problem | 1 |
| not applicable | 1 |
| not done | 1 |

Total: 163. Decisions are listed in `hig-decisions.md`; work handed to other owners is in `hig-handoffs.md`; visual regressions from the fixes are in `hig-screenshot-review.md`.

| Area | # | Finding | Severity | Size | Status |
|---|---|---|---|---|---|
| active-workout | 1 | Swapping an exercise throws away the sets already logged for it, without asking | hurts usability (data lo | S | waiting on a decision |
| active-workout | 2 | The rest-over notification is scheduled once and never moved or removed | hurts usability | M | waiting on a decision |
| active-workout | 3 | The control that logs a set is 32 pt wide | hurts usability | M | fixed |
| active-workout | 4 | Tapping the Live Activity does not open the workout | hurts usability | S | fixed |
| active-workout | 5 | The rest timer in the app can only be watched | hurts usability | M | fixed |
| active-workout | 6 | There is no pause, and the Live Activity has a paused state nothing can reach | hurts usability | M | waiting on a decision |
| active-workout | 7 | Finishing a workout gives no summary and no confirmation, and an empty one is saved | hurts usability | M | waiting on a decision |
| active-workout | 8 | The tracker is a full-screen modal with no visible way out | hurts usability | S | fixed |
| active-workout | 9 | The Live Activity's rows are 38 pt high whatever the text size, and so are its buttons | hurts usability — **by a | M | waiting on a decision |
| active-workout | 10 | Alerts are used for choices and for a routine step | hurts usability | M | waiting on a decision |
| active-workout | 11 | "Play Sound" plays nothing in the app, and will stop the user's music when it does | hurts usability | S | waiting on a decision |
| active-workout | 12 | Half the Live Activity and the Today widget cannot be translated | hurts usability (Spanish | S | fixed |
| active-workout | 13 | Discarding a workout is called three different things | polish | S | fixed |
| active-workout | 14 | Live Activity text is small, regular weight and secondary | polish | S | fixed |
| active-workout | 15 | A finished workout stays on the Lock Screen for up to four hours | polish | S | fixed |
| active-workout | 16 | The Live Activity cannot be turned off from inside the app | polish | S | waiting on a decision |
| active-workout | 17 | VoiceOver is given the asset name and no workout progress | polish — **unverified, n | S | fixed |
| active-workout | 18 | The set keyboard is silent | polish | S | fixed |
| active-workout | 19 | Widgets: descriptions, links and tinted appearance | polish | S | fixed |
| analytics-charts | 1 | Weight and measurements can only be logged in whole units | hurts usability | M | waiting on a decision |
| analytics-charts | 2 | Every analytics screen is a sheet, and they stack three and four deep | hurts usability | L | waiting on a decision |
| analytics-charts | 3 | The Nutrition analytics sheet has no close button | hurts usability | S | fixed |
| analytics-charts | 4 | Card titles are cut to one line in a grid that is always two columns | hurts usability | S | needs a change elsewhere |
| analytics-charts | 5 | A card is a button whose VoiceOver label is whatever happens to be inside it | hurts usability — **unve | M | needs a change elsewhere |
| analytics-charts | 6 | Series cannot be told apart: two lines in one colour, macros by colour alone | hurts usability | M | fixed |
| analytics-charts | 7 | A selected chart row draws white text on the series colour | hurts usability — **need | M | needs a package change |
| analytics-charts | 8 | Twenty-two of fifty-two nutrient cards are permanently "Not Tracked", at half opacity | hurts usability | S | waiting on a decision |
| analytics-charts | 9 | "See All" is a 12 pt text button with no padding | hurts usability | S | needs a change elsewhere |
| analytics-charts | 10 | Four layouts cannot grow with the text size | hurts usability at acces | M | needs a change elsewhere |
| analytics-charts | 11 | Metric screens show "No data" while they are still loading | polish | M | needs a change elsewhere |
| analytics-charts | 12 | `ActivityRingView` borrows the Activity ring's look for calories | polish, App Review expos | S | needs a change elsewhere |
| analytics-charts | 13 | The Health app is called "Health" | polish | S | fixed |
| analytics-charts | 14 | Chart descriptions for VoiceOver are thin or describe the drawing | polish | M | needs a change elsewhere |
| analytics-charts | 15 | The weekly target grid has no title and no key | polish | S | fixed |
| analytics-charts | 16 | Progress Photos: delete is only in a context menu, and Close sits beside Back | polish | S | fixed |
| analytics-charts | 17 | Energy Balance wording | polish | S | fixed |
| dashboard-social | 1 | The app schedules reminders nobody asked for, and nothing in the app turns them off | hurts usability (App Rev | M | waiting on a decision |
| dashboard-social | 2 | Reporting is two alerts: four reasons with no Cancel, then a text field | hurts usability | M | already fixed / not a problem |
| dashboard-social | 3 | The Dashboard's carousel cards have a fixed 200 pt body | hurts usability (at larg | M | fixed |
| dashboard-social | 4 | Controls with a hit region well under 44 pt | hurts usability | M | fixed |
| dashboard-social | 5 | A failed load is shown as "nothing here yet" | hurts usability | M | fixed |
| dashboard-social | 6 | Reply, Report, Delete and Remove exist only as swipe actions | hurts usability | S | fixed |
| dashboard-social | 7 | Tapping a notification stacks sheets on the Notifications sheet | hurts usability | M | waiting on a decision |
| dashboard-social | 8 | Up to ten settings rows sit above the notifications themselves | hurts usability | M | waiting on a decision |
| dashboard-social | 9 | The Notifications screen blanks to a spinner on every load, including pull to refresh | polish | S | fixed |
| dashboard-social | 10 | Every push shows a banner and plays a sound while the app is open | polish | S | needs a change elsewhere |
| dashboard-social | 11 | No notification sets an interruption level, and the badge is always 1 | polish | M | waiting on a decision |
| dashboard-social | 12 | Notification copy: capitalization, punctuation, emoji, generic titles, English only | polish | M | needs a change elsewhere |
| dashboard-social | 13 | Four ways to share a workout, and the Share button is the one without the link | polish | M | waiting on a decision |
| dashboard-social | 14 | Alerts: a title of "Error", alerts that only inform, a choice inside an alert, mixed capitalization | polish | M | fixed |
| dashboard-social | 15 | User-facing strings that bypass the string catalog | polish | M | fixed |
| dashboard-social | 16 | Labels that do not say what the control does | polish | S | fixed |
| dashboard-social | 17 | Profile's "Rate us" asks "enjoying the app?" before the system prompt | polish | S | not applicable |
| foundations | 1 | Typed decimals are parsed with `Double(_:)`, which does not accept a decimal comma | blocks people (in region | M | fixed |
| foundations | 2 | A calendar day reads as "M", "14" to VoiceOver, and goal met or missed is red against green | hurts usability | S | waiting on a decision |
| foundations | 3 | Text that matters is capped, shrunk or boxed in at large sizes | hurts usability | L | waiting on a decision |
| foundations | 4 | Controls under 44 pt, from four repeated habits | hurts usability | M | fixed |
| foundations | 5 | Nineteen swipe actions, and for most of them the swipe is the only way | hurts usability | M | fixed |
| foundations | 6 | Strings passed as `String` never reach the catalog, so translations that exist are not shown | hurts usability | M | fixed |
| foundations | 7 | Hero and placeholder images are read out by asset name | hurts usability (VoiceOv | S | fixed |
| foundations | 8 | The launch screen is a full-colour collage with the app name on it | polish | S | needs a change elsewhere |
| foundations | 9 | Clear glass over a plain list, and bar material behind pinned headers | polish | S | fixed in part |
| foundations | 10 | Eight chevrons point the same way in every language | polish (no right-to-left | S | fixed in part |
| foundations | 11 | Three animations skip the reduced-motion helpers, and the lint rule cannot see them | polish | S | fixed in part |
| foundations | 12 | The app icon is a flat image with its own rounded shape drawn in | polish | M | waiting on a decision |
| nutrition | 1 | Decimal amounts cannot be typed where the decimal separator is a comma | blocks people | M | fixed |
| nutrition | 2 | Editing a logged item from the timeline saves nothing, and plays the success haptic | blocks people | S | fixed |
| nutrition | 3 | Create Food's "Scan Barcode" can never return a barcode | blocks people | M | fixed |
| nutrition | 4 | With camera access denied the scanner says the device is unsupported, and the fallback is hidden | blocks people | M | fixed |
| nutrition | 5 | Adding a food gives no sign that it was added | hurts usability | M | waiting on a decision |
| nutrition | 6 | The AI features do not say they are AI, that data leaves the device, or that results are estimates | hurts usability (trust), | M | waiting on a decision |
| nutrition | 7 | Create Food's nutrition form shows units it does not use, and two of its three modes are placeholders | hurts usability (wrong d | M | fixed |
| nutrition | 8 | The Food Packaging step looks interactive where it is not, and drops the photos | hurts usability | M | waiting on a decision |
| nutrition | 9 | Modal screens stack up to four deep, and several have no Close button | hurts usability | L | fixed in part |
| nutrition | 10 | Closing a create flow throws the form away without asking | hurts usability | M | fixed |
| nutrition | 11 | Saving shows no progress and the button stays live | hurts usability | M | fixed |
| nutrition | 12 | People are shown raw error text | hurts usability | M | fixed |
| nutrition | 13 | Add Meal has no title and a crowded toolbar; the draft bar says "Elapsed" | hurts usability | M | fixed |
| nutrition | 14 | The camera purpose string is passive and does not say where the photo goes | hurts usability (trust), | S | needs a change elsewhere |
| nutrition | 15 | Create Recipe's Next button is always enabled and objects afterwards | polish | S | fixed |
| nutrition | 16 | The draft-meal prompt is an alert offering three choices | polish | S | fixed |
| nutrition | 17 | Status text over the live camera has no backing, or is secondary colour on glass | polish | S | fixed |
| nutrition | 18 | Wording and control details that differ from screen to screen | polish | M | fixed |
| nutrition | 19 | Repeated VoiceOver labels, and two actions reachable only by gesture | polish | S | fixed in part |
| nutrition | 20 | Four figures in a row are unlikely to survive the largest text sizes | polish — **unverified, m | M | not done |
| onboarding-data-steps | 1 | The goal steps accept and display unsafe values with no feedback | hurts usability (health  | M | waiting on a decision |
| onboarding-data-steps | 2 | People are asked to accept a privacy notice the screen neither shows nor links | hurts usability (trust), | M | waiting on a decision |
| onboarding-data-steps | 3 | Gender is required, offers two options, and gives no reason | hurts usability (inclusi | M | waiting on a decision |
| onboarding-data-steps | 4 | No data-entry step says why it is asking or whether the answer is required | hurts usability | S | waiting on a decision |
| onboarding-data-steps | 5 | Units start as metric for everyone, and the choice is asked twice | hurts usability | S | fixed |
| onboarding-data-steps | 6 | The rate slider's end labels are unitless kilograms, and its value is not described | hurts usability | S | fixed |
| onboarding-data-steps | 7 | Spanish users get the wrong goal message, and several strings never reach the catalog | hurts usability | M | fixed in part |
| onboarding-data-steps | 8 | The calorie-floor step uses terms it does not define, and warns without saying of what | hurts usability (health  | S | waiting on a decision |
| onboarding-data-steps | 9 | The wheels cannot represent some bodies, and one limit is applied silently | hurts usability (inclusi | S | fixed |
| onboarding-data-steps | 10 | The back button is hidden at three points, so entered data cannot be corrected | hurts usability | S | fixed |
| onboarding-data-steps | 11 | The diet questions and the Strava step are setup that could wait | hurts usability | S | waiting on a decision |
| onboarding-data-steps | 12 | Cancelling Strava sign-in shows "Connection Failed" with a raw system error | hurts usability | S | fixed |
| onboarding-data-steps | 13 | Health data is typed in by hand, with no offer to read it from Apple Health | hurts usability | M | waiting on a decision |
| onboarding-data-steps | 14 | The Strava button's label and two status texts fall below the contrast minimum | polish — computed, not m | S | fixed |
| onboarding-data-steps | 15 | A chosen weight loss is drawn in the error colour | polish | S | fixed |
| onboarding-data-steps | 16 | Copy: "we" throughout, one typo, and undefined abbreviations | polish | S | fixed |
| onboarding-data-steps | 17 | The photo control cannot undo a choice, keeps a stale label, and fails silently | polish | S | fixed |
| onboarding-data-steps | 18 | Wheels list values from high to low, and the birth date uses the calendar style | polish — the second half | S | fixed |
| profile-settings-paywalls | 1 | Nothing on the Account screen can be saved | blocks people | S | fixed |
| profile-settings-paywalls | 2 | Someone who will not subscribe cannot delete their account, sign out, or leave the paywall | blocks people, App Revie | M | waiting on a decision |
| profile-settings-paywalls | 3 | Deleting an account does not revoke the Sign in with Apple token | blocks people (privacy), | S | needs a change elsewhere |
| profile-settings-paywalls | 4 | Every legal link opens apple.com | hurts usability (trust), | S | waiting on a decision |
| profile-settings-paywalls | 5 | The deletion alert says nothing about the subscription, the re-authentication or the timing | hurts usability | M | waiting on a decision |
| profile-settings-paywalls | 6 | The Subscription row sells to people who already subscribe, and nothing manages a subscription | hurts usability | M | fixed |
| profile-settings-paywalls | 7 | Cancelling a purchase, or Ask to Buy, raises an "Error" alert | hurts usability | M | fixed |
| profile-settings-paywalls | 8 | The custom paywall does not say what is being bought | hurts usability, App Rev | M | waiting on a decision |
| profile-settings-paywalls | 9 | Swiping the Profile sheet away discards gym profile edits | hurts usability (data lo | M | fixed |
| profile-settings-paywalls | 10 | Settings is a modal that stacks three more modals | hurts usability | M | waiting on a decision |
| profile-settings-paywalls | 11 | Strava: Disconnect is one stray tap away, the row does not update, and a test button ships | hurts usability | M | fixed |
| profile-settings-paywalls | 12 | "Rate us" asks "Are you enjoying AIChat?" | hurts usability | S | fixed in part |
| profile-settings-paywalls | 13 | Seven add-equipment forms have unlabeled fields and validate by alert | hurts usability (accessi | M | fixed |
| profile-settings-paywalls | 14 | Account does not say how the person is signed in | hurts usability | S | fixed |
| profile-settings-paywalls | 15 | Three settings ignore what the system already knows | hurts usability | M | fixed |
| profile-settings-paywalls | 16 | Seven rows lead to a screen or alert that says the feature does not exist | hurts usability | S | waiting on a decision |
| profile-settings-paywalls | 17 | Settings copy: truncated explanations, state repeated as a subtitle, a stale value | polish | S | fixed |
| profile-settings-paywalls | 18 | Pickers presented as sheets have no way to cancel, and one choice is an alert | polish | S | fixed |
| profile-settings-paywalls | 19 | "Edit Weights" is a text link about 20 pt tall | polish | S | fixed |
| profile-settings-paywalls | 20 | Profile is blank when the first name is missing | polish | S | fixed |
| shell-navigation | 1 | The "blocking" loading modal can be tapped away, and says nothing to VoiceOver | hurts usability | S | fixed |
| shell-navigation | 2 | The loading modal also covers reads, where the HIG asks for content first | hurts usability | M | needs a change elsewhere |
| shell-navigation | 3 | The rating prompt asks "Are you enjoying AIChat?" | hurts usability | S | waiting on a decision |
| shell-navigation | 4 | `CustomModalView` is a hand-built alert that misses what the system alert gives for free | hurts usability | M | fixed in part |
| shell-navigation | 5 | Typed input is lost without a warning when a form is closed or swiped away | hurts usability | M | needs a change elsewhere |
| shell-navigation | 6 | Sheets open sheets, three deep | hurts usability | L | waiting on a decision |
| shell-navigation | 7 | The workout tracker has no visible way out | hurts usability | S | needs a change elsewhere |
| shell-navigation | 8 | Alerts are used as pickers and as forms | hurts usability | M | fixed in part |
| shell-navigation | 9 | Thirty-two error alerts are titled "Error" | hurts usability | M | fixed in part |
| shell-navigation | 10 | A first launch without a connection fails silently | hurts usability | M | fixed in part |
| shell-navigation | 11 | The launch screen is a splash screen | polish | S | needs a change elsewhere |
| shell-navigation | 12 | Two screens replace the system back button with a drawn chevron | polish | M | needs a change elsewhere |
| shell-navigation | 13 | The tab bar accessory ignores its inline placement and has two lines in a fixed height | polish | M | waiting on a decision |
| shell-navigation | 14 | Toasts and banners vanish after four seconds and are never announced | polish | S | fixed |
| shell-navigation | 15 | No keyboard shortcuts or menu commands for iPad and Mac | polish | S | waiting on a decision |
| shell-navigation | 16 | Alerts that only inform | polish | S | fixed in part |
| shell-navigation | 17 | Toolbar crowding and a text button beside a symbol | polish | S | needs a change elsewhere |
| shell-navigation | 18 | Search: a failed people search reads as "no results" | polish | S | fixed |
| shell-navigation | 19 | Nothing is restored on relaunch | polish | S | fixed |
| training-library | 1 | Libraries open as sheets, and sheets then stack three and four deep | hurts usability | L | waiting on a decision |
| training-library | 2 | "Edit Workout" on a finished session opens no editor, and Save hides in the More menu | hurts usability | S | waiting on a decision |
| training-library | 3 | Unsaved work is thrown away by a swipe, a close or a back, with no question asked | hurts usability | M | fixed |
| training-library | 4 | Alerts are used as menus, and one asks "Yes / No" | hurts usability | M | fixed |
| training-library | 5 | The Start Time sheet has Done and nothing else, and has already saved | hurts usability | S | fixed |
| training-library | 6 | The program editor replaces Back with a chevron that discards everything | hurts usability | S | fixed |
| training-library | 7 | Delete is reachable only by swipe, and Share only by touch and hold | hurts usability | M | fixed |
| training-library | 8 | Fields and swatches that VoiceOver cannot name | hurts usability (VoiceOv | S | fixed |
| training-library | 9 | Tap targets under 44 pt | hurts usability | M | fixed |
| training-library | 10 | Exercise filter chips: the active state cannot be seen, and each pick closes the menu | hurts usability | S | fixed |
| training-library | 11 | Blank and dead-end empty states | hurts usability | S | fixed in part |
| training-library | 12 | Exercises in a workout cannot be reordered | hurts usability | S | fixed |
| training-library | 13 | Internal identifiers shown as text | polish | S | fixed |
| training-library | 14 | Invalid input is refused without saying why | polish | M | fixed |
| training-library | 15 | A sheet to choose between three commands | polish | S | waiting on a decision |
| training-library | 16 | Short option lists open a sheet, and the muscle picker is a grid of one image | polish | M | waiting on a decision |
| training-library | 17 | Saves give no sign of progress | polish | S | fixed |
| training-library | 18 | Alert titles: "Error", and two capitalisation styles | polish | S | fixed |
| training-library | 19 | Wording | polish | S | fixed |
| training-library | 20 | Opaque bar material behind the calendar header | polish | S | fixed |
| training-library | 21 | Completed days are dimmed to 30% | polish | S | fixed |
