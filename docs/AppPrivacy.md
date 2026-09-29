# App Privacy answers (App Store Connect)

What to enter under **App Privacy** in App Store Connect, and why. The machine-readable twin is
`DialedIn/SupportingFiles/PrivacyInfo.xcprivacy` (app) and
`WorkoutSessionActivity/PrivacyInfo.xcprivacy` (widget / Live Activity extension);
`PrivacyManifestTests` checks both. When a feature starts sending a new kind of data off the
device, update this file, the manifest and the answers in App Store Connect together.

"Collected" means it leaves the device and is kept longer than it takes to answer the request.
Real-time-only processing (a food search query, a photo sent to `foodAnalyze` and discarded, a
Siri intent handled in-process, a share card saved to Photos) is not collection.

## Tracking: **No**

- No ad SDK, no data broker, no cross-app/cross-site linking. `NSPrivacyTracking` is `false`
  and there are no tracking domains.
- The app no longer shows the App Tracking Transparency prompt (it asked for tracking it never
  did). Without ATT authorisation the IDFA is zeros, so the IDFA support inside Firebase
  Analytics' `GoogleAppMeasurement` never has an advertising ID to collect.
- `NSUserTrackingUsageDescription` and `NSCalendarsUsageDescription` stay in the build
  settings on purpose: `SwiftfulUtilities` links `ATTrackingManager` and `EKEventStore`, and
  App Store Connect rejects a binary that references those APIs without a purpose string
  (ITMS-90683).
- If you ever link a Firebase project to Google Ads or turn on ad personalisation, this
  answer changes to **Yes**. You would then need the ATT prompt back and "Used to Track You"
  entries.

## Data types

Every type below is **linked to the user**. The Firebase `uid` is on every Firestore document,
analytics events carry `user_id` (for example `TrainingProgramManager`), and in the dev
configuration RevenueCat receives the email together with the Mixpanel and Firebase analytics IDs.
None of them is used for tracking.

| Data type (App Store Connect) | Collected | Linked | Tracking | Purposes | Where it comes from |
|---|---|---|---|---|---|
| Contact Info → Name | Yes | Yes | No | App Functionality | First/last name on the profile (`UserModel`), shown to circle members |
| Contact Info → Email Address | Yes | Yes | No | App Functionality | Sign in with Apple / Google via Firebase Auth. Also sent to RevenueCat as a subscriber attribute (dev) |
| Health & Fitness → Health | Yes | Yes | No | App Functionality | Body weight, circumference measurements, body fat and HealthKit reads (weight, steps), synced to Firestore |
| Health & Fitness → Fitness | Yes | Yes | No | App Functionality | Workout sessions, sets, PRs, programs, streaks, steps, Strava imports. Shared with the user's accountability circle |
| User Content → Photos or Videos | Yes | Yes | No | App Functionality | Profile photo, progress photos, and food / recipe / gym / workout images, uploaded to Firebase Storage |
| User Content → Other User Content | Yes | Yes | No | App Functionality | Meal and food logs, custom foods, recipes, exercises, templates, session and exercise notes, mentions, nudges, AI chat messages, reports |
| Identifiers → User ID | Yes | Yes | No | App Functionality, Analytics | Firebase `uid`, the RevenueCat app user ID, and `user_id` on analytics events |
| Identifiers → Device ID | Yes | Yes | No | App Functionality, Analytics | FCM push token stored on the user, IDFV sent as an analytics user property, and the Firebase app instance ID and Mixpanel distinct ID |
| Purchases → Purchase History | Yes | Yes | No | App Functionality | Subscription status via RevenueCat (dev) and StoreKit entitlements (prod) |
| Location → Coarse Location | Yes | Yes | No | Analytics | Mixpanel and Firebase Analytics derive city/country from the IP address. Locale country and time zone are also sent as user properties. No Core Location |
| Usage Data → Product Interaction | Yes | Yes | No | Analytics | Screen and event analytics: Firebase Analytics and Mixpanel |
| Diagnostics → Crash Data | Yes | Yes | No | App Functionality | Firebase Crashlytics. Severe log events carry the same parameters as analytics |
| Diagnostics → Performance Data | Yes | Yes | No | App Functionality | Crashlytics diagnostics, plus thermal state, low-power mode and memory in analytics user properties |
| Diagnostics → Other Diagnostic Data | Yes | Yes | No | App Functionality, Analytics | Device model, OS version, screen size, battery state and app version (`Utilities.offDeviceEventParameters`) |

### Not collected

| Data type | Why not |
|---|---|
| Contacts | Invites are links. The app never reads the address book (no `Contacts` framework) |
| Precise Location | No Core Location. Strava imports carry no route data into the app |
| Phone Number, Physical Address, Other Contact Info | Never asked for |
| Financial Info, Payment Info, Credit Info | Apple / RevenueCat handle payment. The app sees entitlements only |
| Sensitive Info | Not collected |
| Browsing History, Search History | Food search queries go to `foodSearch` and are answered in real time, not stored |
| Emails or Text Messages, Audio Data, Gameplay Content, Customer Support | None. Reports are covered by Other User Content |
| Advertising Data | No ads |

## Required-reason APIs (privacy manifest)

Third-party SDKs (Firebase, Mixpanel, RevenueCat, SDWebImage, GoogleUtilities, gRPC, …) ship
their own `PrivacyInfo.xcprivacy`, and Xcode merges them into the privacy report. The app's own
manifest covers the app's code and the `Swiftful*` source packages, which are compiled into the
app and have no manifest of their own.

| Category | Reason | Used by |
|---|---|---|
| UserDefaults | `CA92.1`: read/write the app's own defaults | Settings, seeding flags, AppState, SwiftfulDataManagers / SwiftfulGamification / SwiftfulRouting / SwiftfulUtilities ratings |
| UserDefaults | `1C8F.1`: App Group shared with the widget | `SharedWorkoutStorage` / `WidgetSnapshot` (`group.com.dialedin.app`) |
| System boot time | `35F9.1`: on-device only | `SwiftfulUtilities.Utilities.systemUptime`, shown only in Dev Settings |

Widget extension manifest: UserDefaults `1C8F.1` only (it reads the App Group snapshot and the
Live Activity state).

Not used anywhere in app or `Swiftful*` code: file timestamp APIs, disk space APIs, active
keyboards. If one is added, declare it and the test's allowed-set check will cover the code.

### Fixed in this pass

`Utilities.eventParameters` includes `utility_system_uptime_days`. It was sent to Firebase
Analytics and Mixpanel as a user property at sign-in, but every allowed boot-time reason forbids
sending boot time, or anything derived from it, off the device. Sign-in now sends
`Utilities.offDeviceEventParameters`, which removes that key. Dev Settings still shows the
full list on the device.

## Permissions the app asks for

| Permission | Purpose string key | Used for |
|---|---|---|
| Health (read / write) | `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` | Weight, steps, workouts |
| Camera | `NSCameraUsageDescription` | Barcode scanning, food photo recognition |
| Photo library (add only) | `NSPhotoLibraryAddUsageDescription` | Saving share cards and images. Picking photos uses `PhotosPicker`, which needs no permission |
| Notifications | none | Pushes for nudges, follows and mentions |
| App Group | entitlement | Widgets and Live Activity read the workout snapshot |
| Siri / App Intents | none | Shortcuts run in-process. Weight they log is covered under Health |
