# Package register

The owner compared Compound against another app's licence list (370 names) on 19 Oct 2026. This
is where each of those packages stands, and what to consider next. Adoption rules: an exact
version at least 14 days old, a permissive licence (MIT, BSD or Apache), SwiftPM support on iOS
(the iOS build has no CocoaPods), and the package wrapped in `app_ui` or a repository so feature
code never imports it. Decisions are in `decisions.md` (19 Oct 2026 rows).

## Where the 370 stand

| | Count | |
|---|---|---|
| Built into Flutter | 72 | Engine libraries (Skia, ICU, Vulkan, HarfBuzz…) listed in the SDK's `sky_engine/LICENSE`; every Flutter app ships them |
| Used directly | 49 | Below |
| Present transitively | 130 | Plugins' platform halves and Dart utilities, e.g. `provider` (via `flutter_bloc`), `rxdart`, `device_info_plus` |
| Not in Compound | 123 | Below |

Counts overlap slightly: `equatable` and a few tooling packages are both engine-listed and pub
packages.

## Used directly

- **Adopted 19 Oct 2026 (#221–#246):** `fuzzy` (in place of `fuzzywuzzy`), `confetti`,
  `image_cropper`, `flutter_image_compress`, `uuid`, `openfoodfacts` (barcode lookup only),
  `screenshot`, `flutter_slidable`, `haptic_feedback`, `another_flushbar` (1.12.x; 2.x adds a
  remote-message service), `shimmer`, `flutter_spinkit`, `home_widget`, `app_links`,
  `quick_actions`, `flutter_soloud`, and `camera` (in place of `flutter_camera_ml_vision`).
- **Before then:** Firebase (core, auth, Firestore, Functions, Storage, Analytics, Crashlytics,
  Messaging, Remote Config, App Check), `go_router`, `google_sign_in`, `purchases_flutter`,
  `health`, `mobile_scanner`, `image_picker`, `share_plus`, `url_launcher`, `wakelock_plus`,
  `in_app_review`, `package_info_plus`, `path_provider`, `shared_preferences`, `http`, `intl`,
  `timezone`, `archive`, `xml`, `equatable`.

## Candidates

| Package | Why | When |
|---|---|---|
| `csv` | Program import parses CSV by hand (`program_repository/lib/src/import/sheet_readers.dart`, a port of Swift's `CSVReader`). Keep its behaviour: UTF-8 with a Latin-1 fallback, empty cells as null | Ready: one small PR |
| `animations` | Shared-axis, fade-through and container-transform transitions, through `AppMotion` so Reduce Motion applies | Ready, if wanted |
| `showcaseview` | One-time tips for hidden features: chart press-and-hold and pinch, quick actions, live label reading. New: Swift had no TipKit | Owner's call |
| `markdown` | Rendering for the coach overhaul (generative UI); replaces the bold/italic parser in `coach/view/coach_message_body.dart` | With the coach overhaul |
| `gleap_sdk` | Support chat, bug reports, feedback. Paid service | Parked |
| `device_info_plus` | Already transitive; use directly to attach the device model to support reports | With Gleap |
| `flutter_svg`, `rive`, `video_player` | Vector illustrations, Rive animations, exercise demo videos | Only once that content exists (the exercise model holds a link, not a video) |

## Not adopted

- **Licence:** `fuzzywuzzy` (GPL-2.0); the Syncfusion packages (commercial or community licence;
  `compound_charts` replaces them).
- **Can't resolve or would harm:** `flutter_camera_ml_vision` (needs `firebase_core` ^1.1 and the
  discontinued `firebase_ml_vision`); `quantify` (conversion factors differ from Swift's stored
  values); `auto_size_text` (shrinks text against the user's size); `firebase_ai` (calls the model
  from the device, skipping the server's consent, premium and quota checks); `carousel_slider`
  (creates an undisposed controller per rebuild; `AppCarousel` runs on `PageView`).
- **Architecture:** `riverpod`, `flutter_riverpod`, `hooks_riverpod`, `riverpod_annotation`,
  `flutter_hooks`, `freezed_annotation` (bloc and equatable); `dio` (`http` suffices); `jiffy` (day
  keys); `material_symbols_icons` (Material icons through `AppSymbols`, owner 18 Oct).
- **Stale (Dart 2 era):** `great_list_view`, `snapping_sheet`, `infinite_listview`, `spring`,
  `ntp`, `supercharged`, `dynamic_height_grid_view`.
- **No feature needs it:** `flame`, `sensors_plus`, `fleather`, `drag_and_drop_lists`,
  `flutter_sticky_header`, `scroll_to_index`, `file_picker` (`file_selector` is used), `open_file`,
  `file_saver`, `extended_image`, `dotted_border`, `email_validator`, `dlibphonenumber`,
  `visibility_detector`, `vibration`, `cupertino_icons`, lint presets (`very_good_analysis` is used).
- **Plumbing nobody picks:** the remaining Dart utilities and every platform half
  (`*_platform_interface`, `*_web`, `*_windows`…).
