# HIG findings index (2026-09-28)

Generated from the nine `hig-*.md` reviews. `Decision` is the reviewer's call on whether a product decision is needed.

| Area | # | Finding | Severity | Size | Decision | Status |
|---|---|---|---|---|---|---|
| active-workout | 1 | Swapping an exercise throws away the sets already logged for it, without asking | hurts usability  | S | yes | open |
| active-workout | 2 | The rest-over notification is scheduled once and never moved or removed | hurts usability | M | yes | open |
| active-workout | 3 | The control that logs a set is 32 pt wide | hurts usability | M | no | open |
| active-workout | 4 | Tapping the Live Activity does not open the workout | hurts usability | S | no | open |
| active-workout | 5 | The rest timer in the app can only be watched | hurts usability | M | no | open |
| active-workout | 6 | There is no pause, and the Live Activity has a paused state nothing can reach | hurts usability | M | yes | open |
| active-workout | 7 | Finishing a workout gives no summary and no confirmation, and an empty one is saved | hurts usability | M | yes | open |
| active-workout | 8 | The tracker is a full-screen modal with no visible way out | hurts usability | S | no | open |
| active-workout | 9 | The Live Activity's rows are 38 pt high whatever the text size, and so are its buttons | hurts usability  | M | yes | open |
| active-workout | 10 | Alerts are used for choices and for a routine step | hurts usability | M | yes | open |
| active-workout | 11 | "Play Sound" plays nothing in the app, and will stop the user's music when it does | hurts usability | S | yes | open |
| active-workout | 12 | Half the Live Activity and the Today widget cannot be translated | hurts usability  | S | no | open |
| active-workout | 13 | Discarding a workout is called three different things | polish | S | no | open |
| active-workout | 14 | Live Activity text is small, regular weight and secondary | polish | S | no | open |
| active-workout | 15 | A finished workout stays on the Lock Screen for up to four hours | polish | S | no | open |
| active-workout | 16 | The Live Activity cannot be turned off from inside the app | polish | S | yes | open |
| active-workout | 17 | VoiceOver is given the asset name and no workout progress | polish — **unver | S | no | open |
| active-workout | 18 | The set keyboard is silent | polish | S | no | open |
| active-workout | 19 | Widgets: descriptions, links and tinted appearance | polish | S | no | open |
| analytics-charts | 1 | Weight and measurements can only be logged in whole units | hurts usability | M | yes | open |
| analytics-charts | 2 | Every analytics screen is a sheet, and they stack three and four deep | hurts usability | L | yes | open |
| analytics-charts | 3 | The Nutrition analytics sheet has no close button | hurts usability | S | no | open |
| analytics-charts | 4 | Card titles are cut to one line in a grid that is always two columns | hurts usability | S | no | open |
| analytics-charts | 5 | A card is a button whose VoiceOver label is whatever happens to be inside it | hurts usability  | M | no | open |
| analytics-charts | 6 | Series cannot be told apart: two lines in one colour, macros by colour alone | hurts usability | M | no | open |
| analytics-charts | 7 | A selected chart row draws white text on the series colour | hurts usability  | M | no | open |
| analytics-charts | 8 | Twenty-two of fifty-two nutrient cards are permanently "Not Tracked", at half opacity | hurts usability | S | yes | open |
| analytics-charts | 9 | "See All" is a 12 pt text button with no padding | hurts usability | S | no | open |
| analytics-charts | 10 | Four layouts cannot grow with the text size | hurts usability  | M | no | open |
| analytics-charts | 11 | Metric screens show "No data" while they are still loading | polish | M | no | open |
| analytics-charts | 12 | `ActivityRingView` borrows the Activity ring's look for calories | polish, App Revi | S | no | open |
| analytics-charts | 13 | The Health app is called "Health" | polish | S | no | open |
| analytics-charts | 14 | Chart descriptions for VoiceOver are thin or describe the drawing | polish | M | no | open |
| analytics-charts | 15 | The weekly target grid has no title and no key | polish | S | no | open |
| analytics-charts | 16 | Progress Photos: delete is only in a context menu, and Close sits beside Back | polish | S | no | open |
| analytics-charts | 17 | Energy Balance wording | polish | S | no | open |
| dashboard-social | 1 | The app schedules reminders nobody asked for, and nothing in the app turns them off | hurts usability  | M | yes | open |
| dashboard-social | 2 | Reporting is two alerts: four reasons with no Cancel, then a text field | hurts usability | M | no | open |
| dashboard-social | 3 | The Dashboard's carousel cards have a fixed 200 pt body | hurts usability  | M | no | open |
| dashboard-social | 4 | Controls with a hit region well under 44 pt | hurts usability | M | no | open |
| dashboard-social | 5 | A failed load is shown as "nothing here yet" | hurts usability | M | no | open |
| dashboard-social | 6 | Reply, Report, Delete and Remove exist only as swipe actions | hurts usability | S | no | open |
| dashboard-social | 7 | Tapping a notification stacks sheets on the Notifications sheet | hurts usability | M | yes | open |
| dashboard-social | 8 | Up to ten settings rows sit above the notifications themselves | hurts usability | M | yes | open |
| dashboard-social | 9 | The Notifications screen blanks to a spinner on every load, including pull to refresh | polish | S | no | open |
| dashboard-social | 10 | Every push shows a banner and plays a sound while the app is open | polish | S | no | open |
| dashboard-social | 11 | No notification sets an interruption level, and the badge is always 1 | polish | M | yes | open |
| dashboard-social | 12 | Notification copy: capitalization, punctuation, emoji, generic titles, English only | polish | M | no | open |
| dashboard-social | 13 | Four ways to share a workout, and the Share button is the one without the link | polish | M | yes | open |
| dashboard-social | 14 | Alerts: a title of "Error", alerts that only inform, a choice inside an alert, mixed capitalization | polish | M | no | open |
| dashboard-social | 15 | User-facing strings that bypass the string catalog | polish | M | no | open |
| dashboard-social | 16 | Labels that do not say what the control does | polish | S | no | open |
| dashboard-social | 17 | Profile's "Rate us" asks "enjoying the app?" before the system prompt | polish | S | no | open |
| foundations | 1 | Typed decimals are parsed with `Double(_:)`, which does not accept a decimal comma | blocks people (i | M | no | open |
| foundations | 2 | A calendar day reads as "M", "14" to VoiceOver, and goal met or missed is red against green | hurts usability | S | yes | open |
| foundations | 3 | Text that matters is capped, shrunk or boxed in at large sizes | hurts usability | L | yes | open |
| foundations | 4 | Controls under 44 pt, from four repeated habits | hurts usability | M | no | open |
| foundations | 5 | Nineteen swipe actions, and for most of them the swipe is the only way | hurts usability | M | no | open |
| foundations | 6 | Strings passed as `String` never reach the catalog, so translations that exist are not shown | hurts usability | M | no | open |
| foundations | 7 | Hero and placeholder images are read out by asset name | hurts usability  | S | no | open |
| foundations | 8 | The launch screen is a full-colour collage with the app name on it | polish | S | no | open |
| foundations | 9 | Clear glass over a plain list, and bar material behind pinned headers | polish | S | no | open |
| foundations | 10 | Eight chevrons point the same way in every language | polish (no right | S | no | open |
| foundations | 11 | Three animations skip the reduced-motion helpers, and the lint rule cannot see them | polish | S | no | open |
| foundations | 12 | The app icon is a flat image with its own rounded shape drawn in | polish | M | yes | open |
| nutrition | 1 | Decimal amounts cannot be typed where the decimal separator is a comma | blocks people | M | no | open |
| nutrition | 2 | Editing a logged item from the timeline saves nothing, and plays the success haptic | blocks people | S | no | open |
| nutrition | 3 | Create Food's "Scan Barcode" can never return a barcode | blocks people | M | no | open |
| nutrition | 4 | With camera access denied the scanner says the device is unsupported, and the fallback is hidden | blocks people | M | no | open |
| nutrition | 5 | Adding a food gives no sign that it was added | hurts usability | M | yes | open |
| nutrition | 6 | The AI features do not say they are AI, that data leaves the device, or that results are estimates | hurts usability  | M | yes | open |
| nutrition | 7 | Create Food's nutrition form shows units it does not use, and two of its three modes are placeholders | hurts usability  | M | no | open |
| nutrition | 8 | The Food Packaging step looks interactive where it is not, and drops the photos | hurts usability | M | yes | open |
| nutrition | 9 | Modal screens stack up to four deep, and several have no Close button | hurts usability | L | no | open |
| nutrition | 10 | Closing a create flow throws the form away without asking | hurts usability | M | no | open |
| nutrition | 11 | Saving shows no progress and the button stays live | hurts usability | M | no | open |
| nutrition | 12 | People are shown raw error text | hurts usability | M | no | open |
| nutrition | 13 | Add Meal has no title and a crowded toolbar; the draft bar says "Elapsed" | hurts usability | M | no | open |
| nutrition | 14 | The camera purpose string is passive and does not say where the photo goes | hurts usability  | S | no | open |
| nutrition | 15 | Create Recipe's Next button is always enabled and objects afterwards | polish | S | no | open |
| nutrition | 16 | The draft-meal prompt is an alert offering three choices | polish | S | no | open |
| nutrition | 17 | Status text over the live camera has no backing, or is secondary colour on glass | polish | S | no | open |
| nutrition | 18 | Wording and control details that differ from screen to screen | polish | M | no | open |
| nutrition | 19 | Repeated VoiceOver labels, and two actions reachable only by gesture | polish | S | no | open |
| nutrition | 20 | Four figures in a row are unlikely to survive the largest text sizes | polish — **unver | M | no | open |
| onboarding-data-steps | 1 | The goal steps accept and display unsafe values with no feedback | hurts usability  | M | yes | open |
| onboarding-data-steps | 2 | People are asked to accept a privacy notice the screen neither shows nor links | hurts usability  | M | yes | open |
| onboarding-data-steps | 3 | Gender is required, offers two options, and gives no reason | hurts usability  | M | yes | open |
| onboarding-data-steps | 4 | No data-entry step says why it is asking or whether the answer is required | hurts usability | S | yes | open |
| onboarding-data-steps | 5 | Units start as metric for everyone, and the choice is asked twice | hurts usability | S | no | open |
| onboarding-data-steps | 6 | The rate slider's end labels are unitless kilograms, and its value is not described | hurts usability | S | no | open |
| onboarding-data-steps | 7 | Spanish users get the wrong goal message, and several strings never reach the catalog | hurts usability | M | no | open |
| onboarding-data-steps | 8 | The calorie-floor step uses terms it does not define, and warns without saying of what | hurts usability  | S | yes | open |
| onboarding-data-steps | 9 | The wheels cannot represent some bodies, and one limit is applied silently | hurts usability  | S | no | open |
| onboarding-data-steps | 10 | The back button is hidden at three points, so entered data cannot be corrected | hurts usability | S | no | open |
| onboarding-data-steps | 11 | The diet questions and the Strava step are setup that could wait | hurts usability | S | yes | open |
| onboarding-data-steps | 12 | Cancelling Strava sign-in shows "Connection Failed" with a raw system error | hurts usability | S | no | open |
| onboarding-data-steps | 13 | Health data is typed in by hand, with no offer to read it from Apple Health | hurts usability | M | yes | open |
| onboarding-data-steps | 14 | The Strava button's label and two status texts fall below the contrast minimum | polish — compute | S | no | open |
| onboarding-data-steps | 15 | A chosen weight loss is drawn in the error colour | polish | S | no | open |
| onboarding-data-steps | 16 | Copy: "we" throughout, one typo, and undefined abbreviations | polish | S | no | open |
| onboarding-data-steps | 17 | The photo control cannot undo a choice, keeps a stale label, and fails silently | polish | S | no | open |
| onboarding-data-steps | 18 | Wheels list values from high to low, and the birth date uses the calendar style | polish — the sec | S | no | open |
| profile-settings-paywalls | 1 | Nothing on the Account screen can be saved | blocks people | S | no | open |
| profile-settings-paywalls | 2 | Someone who will not subscribe cannot delete their account, sign out, or leave the paywall | blocks people, A | M | yes | open |
| profile-settings-paywalls | 3 | Deleting an account does not revoke the Sign in with Apple token | blocks people (p | S | no | open |
| profile-settings-paywalls | 4 | Every legal link opens apple.com | hurts usability  | S | yes | open |
| profile-settings-paywalls | 5 | The deletion alert says nothing about the subscription, the re-authentication or the timing | hurts usability | M | yes | open |
| profile-settings-paywalls | 6 | The Subscription row sells to people who already subscribe, and nothing manages a subscription | hurts usability | M | no | open |
| profile-settings-paywalls | 7 | Cancelling a purchase, or Ask to Buy, raises an "Error" alert | hurts usability | M | no | open |
| profile-settings-paywalls | 8 | The custom paywall does not say what is being bought | hurts usability, | M | yes | open |
| profile-settings-paywalls | 9 | Swiping the Profile sheet away discards gym profile edits | hurts usability  | M | no | open |
| profile-settings-paywalls | 10 | Settings is a modal that stacks three more modals | hurts usability | M | yes | open |
| profile-settings-paywalls | 11 | Strava: Disconnect is one stray tap away, the row does not update, and a test button ships | hurts usability | M | no | open |
| profile-settings-paywalls | 12 | "Rate us" asks "Are you enjoying AIChat?" | hurts usability | S | no | open |
| profile-settings-paywalls | 13 | Seven add-equipment forms have unlabeled fields and validate by alert | hurts usability  | M | no | open |
| profile-settings-paywalls | 14 | Account does not say how the person is signed in | hurts usability | S | no | open |
| profile-settings-paywalls | 15 | Three settings ignore what the system already knows | hurts usability | M | no | open |
| profile-settings-paywalls | 16 | Seven rows lead to a screen or alert that says the feature does not exist | hurts usability | S | yes | open |
| profile-settings-paywalls | 17 | Settings copy: truncated explanations, state repeated as a subtitle, a stale value | polish | S | no | open |
| profile-settings-paywalls | 18 | Pickers presented as sheets have no way to cancel, and one choice is an alert | polish | S | no | open |
| profile-settings-paywalls | 19 | "Edit Weights" is a text link about 20 pt tall | polish | S | no | open |
| profile-settings-paywalls | 20 | Profile is blank when the first name is missing | polish | S | no | open |
| shell-navigation | 1 | The "blocking" loading modal can be tapped away, and says nothing to VoiceOver | hurts usability | S | no | open |
| shell-navigation | 2 | The loading modal also covers reads, where the HIG asks for content first | hurts usability | M | no | open |
| shell-navigation | 3 | The rating prompt asks "Are you enjoying AIChat?" | hurts usability | S | yes | open |
| shell-navigation | 4 | `CustomModalView` is a hand-built alert that misses what the system alert gives for free | hurts usability | M | no | open |
| shell-navigation | 5 | Typed input is lost without a warning when a form is closed or swiped away | hurts usability | M | no | open |
| shell-navigation | 6 | Sheets open sheets, three deep | hurts usability | L | yes | open |
| shell-navigation | 7 | The workout tracker has no visible way out | hurts usability | S | no | open |
| shell-navigation | 8 | Alerts are used as pickers and as forms | hurts usability | M | no | open |
| shell-navigation | 9 | Thirty-two error alerts are titled "Error" | hurts usability | M | no | open |
| shell-navigation | 10 | A first launch without a connection fails silently | hurts usability | M | no | open |
| shell-navigation | 11 | The launch screen is a splash screen | polish | S | no | open |
| shell-navigation | 12 | Two screens replace the system back button with a drawn chevron | polish | M | no | open |
| shell-navigation | 13 | The tab bar accessory ignores its inline placement and has two lines in a fixed height | polish | M | yes | open |
| shell-navigation | 14 | Toasts and banners vanish after four seconds and are never announced | polish | S | no | open |
| shell-navigation | 15 | No keyboard shortcuts or menu commands for iPad and Mac | polish | S | yes | open |
| shell-navigation | 16 | Alerts that only inform | polish | S | no | open |
| shell-navigation | 17 | Toolbar crowding and a text button beside a symbol | polish | S | no | open |
| shell-navigation | 18 | Search: a failed people search reads as "no results" | polish | S | no | open |
| shell-navigation | 19 | Nothing is restored on relaunch | polish | S | no | open |
| training-library | 1 | Libraries open as sheets, and sheets then stack three and four deep | hurts usability | L | yes | open |
| training-library | 2 | "Edit Workout" on a finished session opens no editor, and Save hides in the More menu | hurts usability | S | yes | open |
| training-library | 3 | Unsaved work is thrown away by a swipe, a close or a back, with no question asked | hurts usability | M | no | open |
| training-library | 4 | Alerts are used as menus, and one asks "Yes / No" | hurts usability | M | no | open |
| training-library | 5 | The Start Time sheet has Done and nothing else, and has already saved | hurts usability | S | no | open |
| training-library | 6 | The program editor replaces Back with a chevron that discards everything | hurts usability | S | no | open |
| training-library | 7 | Delete is reachable only by swipe, and Share only by touch and hold | hurts usability | M | no | open |
| training-library | 8 | Fields and swatches that VoiceOver cannot name | hurts usability  | S | no | open |
| training-library | 9 | Tap targets under 44 pt | hurts usability | M | no | open |
| training-library | 10 | Exercise filter chips: the active state cannot be seen, and each pick closes the menu | hurts usability | S | no | open |
| training-library | 11 | Blank and dead-end empty states | hurts usability | S | no | open |
| training-library | 12 | Exercises in a workout cannot be reordered | hurts usability | S | no | open |
| training-library | 13 | Internal identifiers shown as text | polish | S | no | open |
| training-library | 14 | Invalid input is refused without saying why | polish | M | no | open |
| training-library | 15 | A sheet to choose between three commands | polish | S | yes | open |
| training-library | 16 | Short option lists open a sheet, and the muscle picker is a grid of one image | polish | M | yes | open |
| training-library | 17 | Saves give no sign of progress | polish | S | no | open |
| training-library | 18 | Alert titles: "Error", and two capitalisation styles | polish | S | no | open |
| training-library | 19 | Wording | polish | S | no | open |
| training-library | 20 | Opaque bar material behind the calendar header | polish | S | no | open |
| training-library | 21 | Completed days are dimmed to 30% | polish | S | no | open |
