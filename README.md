# Compound

[![CI](https://github.com/andrewcoyle1/Compound/actions/workflows/ci.yml/badge.svg)](https://github.com/andrewcoyle1/Compound/actions/workflows/ci.yml)

A production-grade fitness app for iPhone, iPad and Mac (Catalyst), built with SwiftUI and a
VIPER-style architecture.

## Features

- **Workout Tracking**: Exercises, sets, reps and rest timers, with iOS Live Activities on the
  Dynamic Island and Lock Screen
- **Training Plans**: Mesocycles and macrocycles run as a queue, with skips and progress analytics
- **Nutrition Logging**: Meals and macros, recipes, Open Food Facts barcode lookup, and food logged
  in other apps imported through Apple Health
- **AI Food Analysis**: Photo, description and nutrition-label analysis via Cloud Functions
- **Apple Health**: Workouts saved with heart rate and active energy; weight and steps imported
- **Body Measurements & Steps**: Weight trends and goals, 18 circumference sites, progress photos,
  daily steps
- **Social & Challenges**: Follow other athletes, a workout feed, and challenges
- **Strava**: Finished workouts uploaded to Strava; the client secret stays on the server
- **Gamification**: Streaks, progress and experience points
- **Analytics & A/B Testing**: Mixpanel (EU data residency) and Firebase, with a built-in
  experiment framework
- **Firebase Backend**: Cloud Firestore for persistence, Cloud Functions for AI and Strava, App
  Check for attestation

## Architecture

- **VIPER Pattern**: Each screen is an Interactor protocol, an `@Observable` Presenter, a SwiftUI
  View and a Router. `CoreInteractor` exposes every manager; screens depend on it through their
  own narrow protocol.
- **Dependency Injection**: `Dependencies(config:)` builds all managers for the selected build
  configuration and registers them in a `DependencyContainer`.
- **SwiftUI + Observation**: Declarative UI with reactive data flow.
- **Package-based infrastructure**: Auth, logging, purchasing, routing, data sync and gamification
  come from the `Swiftful*` Swift packages, surfaced through `*+Alias.swift` typealiases.

See [CLAUDE.md](CLAUDE.md) for the full architecture reference and
[docs/codebase-map.md](docs/codebase-map.md) for where every file lives.

## Technologies

- Swift 6, SwiftUI, Observation
- HealthKit, ActivityKit, SwiftData
- Firebase (Firestore, Auth, Analytics, Crashlytics, App Check, Cloud Functions)
- Genkit + Vertex AI (server-side AI)
- Google Sign-In, Sign in with Apple
- RevenueCat (In-App Purchases) / StoreKit
- Mixpanel (Analytics)
- Open Food Facts, Strava
- Swift Package Manager
- Swift Testing, XCTest, SwiftLint
- GitHub Actions (CI and release)

## Setup Instructions

### Prerequisites

- Xcode 26.6 or later (releases are archived with Xcode 27.0)
- iOS 26.0+ deployment target
- Swift 6 language mode (test and extension targets still build in Swift 5 mode)
- SwiftLint 0.59.1, the version CI pins, for `swiftlint` to run locally

### Configuration

1. **Clone the repository**
   ```bash
   git clone https://github.com/andrewcoyle1/Compound.git
   cd Compound
   ```

2. **Install dependencies**

   Dependencies are managed with Swift Package Manager — there is nothing to install by hand.
   Xcode resolves them when you open the project.

3. **Configure API Keys**
   - Copy `Compound/Utilities/Keys.swift.example` to `Compound/Utilities/Keys.swift`
   - Fill in the 33 constants:
     - OpenAI API key (if using AI features)
     - Mixpanel project token
     - RevenueCat public SDK keys, one for dev and one for prod
     - Strava client ID. The client secret is not in the app: it is the `STRAVA_CLIENT_SECRET`
       Cloud Functions secret, used by the `stravaToken` function.
     - 28 `*ManagerKey` strings — arbitrary names used as local-persistence paths. Keep them
       stable once chosen; renaming one orphans data already stored under the old name.
   - **Note**: `Keys.swift` is gitignored. You must create it locally for the app to build.

4. **Configure Firebase**
   - Copy `Compound/SupportingFiles/GoogleServicePLists/GoogleService-Info-Example.plist` to,
     in the same folder:
     - `GoogleService-Info-Dev.plist` (for development)
     - `GoogleService-Info-Prod.plist` (for production)
   - Fill in your Firebase project credentials from the Firebase Console
   - **Note**: These files are gitignored for security. You must create them locally for the app to build.

5. **Configure Google Sign-In & URL schemes**
   - Copy `Compound/Info.plist.example` to `Compound/Info.plist`
   - The example already carries the `REVERSED_CLIENT_ID` for both Firebase projects and the
     `compound` deep-link scheme, so for this project it is a straight copy. If you point the app
     at your own Firebase projects, replace each reversed client ID with the one from your
     `GoogleService-Info` plists.
   - **Note**: `Info.plist` is gitignored. Google Sign-In fails at runtime without it.

6. **Open the project**
   ```bash
   open Compound.xcodeproj
   ```
   Then pick a scheme: `Compound - Development`, `Compound - Mock` (no backend required), or
   `Compound` (production).

### Build Configurations

| Scheme | Configuration | Backend |
|---|---|---|
| `Compound - Development` | Debug | Firebase dev project |
| `Compound - Mock` | Mock | Mock services only, no Firebase |
| `Compound` | Release | Firebase prod project |

## Project Structure

```
Compound/
├── Core/                     # VIPER modules (Today, Training, Nutrition, Social, Profile, ...)
├── Components/               # Reusable UI components and the design system
├── Managers/                 # Domain managers resolved through CoreInteractor
├── Root/                     # App entry point, DI container, CoreInteractor/CoreRouter
├── Extensions/               # Swift/SwiftUI extensions
├── Utilities/                # Helpers, constants, Keys.swift
└── SupportingFiles/          # GoogleService plists, prebuilt exercise/workout JSON

WorkoutSessionActivity/       # Live Activity / Dynamic Island widget extension
Shared/                       # Code shared between the app and the widget extension
functions/                    # Firebase Cloud Functions (Node, Genkit/Vertex AI)
CompoundUnitTests/            # Unit tests
CompoundUITests/              # UI tests
docs/                         # Codebase map, release checklist, privacy notes, reviews
```

## Testing

Run the unit tests:
```bash
xcodebuild test -project Compound.xcodeproj -scheme 'Compound - Development' \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skip-testing:CompoundUITests
```

The unit suite is about 3,750 tests in `CompoundUnitTests/` and takes under three minutes. One
suite runs in about forty-five seconds with `-only-testing:CompoundUnitTests/<Suite>`. Skip the UI
bundle for anything routine: it is three tests, one of them chronically flaky, and a single flake
there prints `** TEST FAILED **` over a clean unit run. See CLAUDE.md for the full cadence.

Cloud Functions tests:
```bash
cd functions && npm test
```

Lint (SwiftLint must be installed):
```bash
swiftlint
```

## CI and Releases

- **CI** (`.github/workflows/ci.yml`) runs on every pull request: SwiftLint in strict mode, the
  unit suite, and the Cloud Functions tests.
- **`main` is protected**: it only accepts a pull request whose checks passed on a branch up to
  date with it. Work happens on `development`, which is merged into `main` to release.
- **Release** (`.github/workflows/release.yml`) runs on each merge to `main` and waits for the
  owner's approval. It then uploads the app to TestFlight and deploys Cloud Functions to the
  production Firebase project. Submitting to App Review stays manual.

See CLAUDE.md for the details, including the secrets and Google Cloud permissions the release uses.

## License

Copyright (c) 2026 Andrew Coyle. All rights reserved.

This project is proprietary and confidential. Unauthorized copying, modification, distribution, or use of this project, via any medium, is strictly prohibited.

## Author

Andrew Coyle
