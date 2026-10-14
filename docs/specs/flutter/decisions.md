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

To regenerate the gitignored dev config, run this from `app/`:

```bash
flutterfire configure --project=compound-development --platforms=ios,android \
  --ios-bundle-id=com.andrewcoyle.compound.flutter.dev --android-package-name=com.andrewcoyle.compound.dev \
  --out=lib/firebase_options_development.dart \
  --ios-out=ios/flavors/development/GoogleService-Info.plist --ios-build-config=Debug-development \
  --android-out=android/app/src/development/google-services.json --yes
```
