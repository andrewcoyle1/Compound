# Compound

[![Flutter](https://github.com/andrewcoyle1/Compound/actions/workflows/flutter.yml/badge.svg)](https://github.com/andrewcoyle1/Compound/actions/workflows/flutter.yml)
[![CI](https://github.com/andrewcoyle1/Compound/actions/workflows/ci.yml/badge.svg)](https://github.com/andrewcoyle1/Compound/actions/workflows/ci.yml)

A fitness app for training, nutrition and body composition, built with Flutter for iOS (iPhone and
iPad) and Android, on a Firebase backend.

## Features

- **Workout tracking**: exercises, sets, reps and rest timers, with a Live Activity on the Dynamic
  Island and Lock Screen
- **Training plans**: mesocycles and macrocycles run as a queue, with smart progression
- **Nutrition logging**: meals and macros, recipes, adaptive calorie targets
- **AI**: food photo, description and label analysis, and an AI coach, via Cloud Functions
- **Health data**: Apple Health and Health Connect workouts, weight and steps
- **Body measurements**: weight trend, goals, circumference sites, progress photos
- **Social**: follows, a workout feed, comments and challenges
- **Strava**: finished workouts uploaded; tokens stay on the server
- **Firebase backend**: Firestore, Cloud Functions (Genkit + Vertex AI), App Check

## Repository

```
app/          # the Flutter app (VGV layered architecture; packages in app/packages/)
contracts/    # data shared by the app and the functions: Firestore contract, fixtures, catalogue
functions/    # Firebase Cloud Functions (Node 22, Genkit/Vertex AI)
hosting/      # Firebase Hosting
scripts/      # UI-contract and Spanish-strings checks, coach parity, screenshots
docs/         # specs, research, reviews, privacy
```

See [CLAUDE.md](CLAUDE.md) for the full reference and [app/README.md](app/README.md) for running
the app.

## Getting started

Requires Flutter 3.47.7 and Node 22.

```bash
git clone https://github.com/andrewcoyle1/Compound.git
cd Compound/app
flutter pub get
flutter run --flavor staging -t lib/main_staging.dart   # in-memory fakes, no Firebase
```

The `development` and `production` flavors need gitignored Firebase config
(`flutterfire configure`) and `app/dart_defines.json`; see [app/README.md](app/README.md).

## Testing

- Flutter: `very_good test --recursive` from `app/` (packages are held at 100% coverage).
- Cloud Functions: `cd functions && npm ci && npm test`.
- `python3 scripts/flutter-ui-check.py` and `python3 scripts/arb-spanish.py --check`.

## CI and releases

- **CI** runs on every pull request: `flutter.yml` for the app and its packages, `ci.yml` for the
  Cloud Functions.
- **`main` is protected**: it only accepts a pull request whose checks passed on a branch up to
  date with it. Work happens on `development`, which is merged into `main` to release.
- **Release** (`release.yml`) runs on each merge to `main` and waits for the owner's approval. It
  deploys Cloud Functions to production, then uploads the Flutter app to TestFlight. Submitting to
  App Review stays manual.

## The SwiftUI app

The original SwiftUI app was removed from this branch on 20 Oct 2026. It is preserved at the
`swift-app-store` tag (the version on the App Store), the `swift-final` tag and the
`archive/swift` branch.

## License

Copyright (c) 2026 Andrew Coyle. All rights reserved.

This project is proprietary and confidential. Unauthorized copying, modification, distribution, or use of this project, via any medium, is strictly prohibited.

## Author

Andrew Coyle
