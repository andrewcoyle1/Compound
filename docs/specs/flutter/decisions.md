# Flutter build: decisions log

Judgement calls made while building without the owner present. Each entry says what was decided,
why, and what would change it. Review these with the `feature/flutter` → `development` PR.

| Date | Slice | Decision | Why | Revisit if |
|---|---|---|---|---|
| 14 Oct 2026 | Plan | Integration branch `feature/flutter`; slice PRs merge into it after CI | Agreed with the owner for hands-off overnight work | — |
| 14 Oct 2026 | M1 scaffold | Android and iOS only; the template's web, macOS and Windows folders were removed | Those are the shipping platforms. Mac Catalyst's replacement is an M6 decision | macOS is wanted at M6 |
| 14 Oct 2026 | M1 scaffold | iOS `development` = `com.andrewcoyle.compound.flutter.dev`, `staging` = `…flutter.stg`; `production` stays `com.andrewcoyle.compound` | Dev builds install beside the Swift dev app; production must become the App Store app at M6 | — |
| 14 Oct 2026 | M1 scaffold | Removed the template's MIT `LICENSE` and its `app/.github` | The repo is proprietary; GitHub never runs workflows from a subfolder | — |
| 14 Oct 2026 | M1 CI | `ci.yml` skips PRs into `feature/flutter`; `flutter.yml` runs only for `app/`, `contracts/` or itself | Slice PRs don't touch Swift, and the Swift jobs take about 30 minutes each. The `feature/flutter` → `development` PR still runs everything | A slice has to change Swift code |
| 14 Oct 2026 | M1 CI | App coverage `min_coverage: 0` (reported); packages are held to 100% in their own tests | As planned: the app's screens churn in the early milestones | M5 |
| 14 Oct 2026 | M1 Firebase | Firebase config files are gitignored, with a placeholder `.example` for CI | **The repo is public.** This matches the Swift app's gitignored plists | — |
| 14 Oct 2026 | M1 Firebase | Registered in `compound-development` only: iOS `1:672259004423:ios:3d911896a395a5599332a2`, Android `1:672259004423:android:a28ac39f010d67f09332a2`, and the standard debug keystore's SHA-1/256 (keystore created on this Mac) | Agreed with the owner: dev project only | — |
| 14 Oct 2026 | M1 contract (#83) | Timestamps in fixtures have millisecond precision, with exactly 3 digits | Swift `Date` is a Double, so sub-microsecond noise can't round-trip | A model needs finer precision |
| 14 Oct 2026 | M1 contract (#83) | Legacy cases come in pairs with `.expected.json` (what Swift writes back after reading them) | Swift and Dart then check exactly the same thing | — |
| 14 Oct 2026 | M1 contract (#83) | Dart decoding is as strict as Swift: an unknown enum value, a missing required field or a wrong type throws (Doubles accept ints) | Swift silently drops documents it can't decode, so Dart must not be more lenient | — |
| 14 Oct 2026 | M1 contract (#83) | Field-name constants go in `…Keys` classes; the Dart models are generated from one field table | The constructor, decoding, encoding and keys can't drift apart | — |
| 14 Oct 2026 | M1 contract (#83) | A `compound_models` CI job at 100% coverage, pinned to Dart 3.13.5 | The app job runs at 0% and wouldn't enforce the package | — |
| 14 Oct 2026 | M1 app_ui (#84) | Colours use the iOS system values, so the Flutter and Swift apps match; the accent is `colorScheme.primary` and on-accent is `onPrimary` | One brand on both platforms | The brand palette changes |
| 14 Oct 2026 | M1 app_ui (#84) | Secondary text is darker than iOS (`#6C6C70` light, `#AEAEB2` dark) | It passes 4.5:1 contrast | — |
| 14 Oct 2026 | M1 app_ui (#84) | System font with iOS sizes and tabular figures, not SF Rounded | SF Rounded can't be bundled on Android | A brand font is chosen |
| 14 Oct 2026 | M1 app_ui (#84) | Icons are Flutter's built-in Material Icons (rounded); no new package | No extra dependency | An icon set is chosen |
| 14 Oct 2026 | M1 app_ui (#84) | `AppFormat` only formats numbers and unit symbols; words and plurals live in the app's ARB strings | app_ui stays free of translations | — |
| 14 Oct 2026 | M1 app_ui (#84) | Deferred to the first screen that needs them: Dashboard, BarChip, sheet presets, `Format.load`, haptics | YAGNI | — |
| 14 Oct 2026 | Maths (#85) | `compound_maths` ports `functions/coach-maths.js` and is checked against `coach-parity.json` with the Swift and JS tolerance (1e-6) | Three copies of the maths, one fixture | — |
| 14 Oct 2026 | Maths (#85) | Dates are `YYYY-MM-DD` day keys, as in the JS; age is passed in by the caller (default 30) | No clock inside the maths | — |
| 14 Oct 2026 | Maths (#85) | `median([])` returns null, as in Swift (the JS returns NaN) | A straight port would crash on a log with no weigh-ins | — |

To regenerate the gitignored dev config, run this from `app/`:

```bash
flutterfire configure --project=compound-development --platforms=ios,android \
  --ios-bundle-id=com.andrewcoyle.compound.flutter.dev --android-package-name=com.andrewcoyle.compound.dev \
  --out=lib/firebase_options_development.dart \
  --ios-out=ios/flavors/development/GoogleService-Info.plist --ios-build-config=Debug-development \
  --android-out=android/app/src/development/google-services.json --yes
```
