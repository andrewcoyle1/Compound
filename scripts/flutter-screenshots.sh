#!/bin/bash
# Screenshots of every screen of the Flutter app's staging flavor, light and
# dark, for a pull request's before and after (docs/specs/flutter/ui-contract.md,
# rule 8). The screens are listed in app/integration_test/screens_test.dart.
#
#   scripts/flutter-screenshots.sh <simulator-udid> [out-dir] [NAME,NAME...]
#
# Writes <NAME>-light.png and <NAME>-dark.png to out-dir (default
# app/build/screenshots). The simulator must already be booted.
set -euo pipefail

udid=${1:?usage: $0 <simulator-udid> [out-dir] [NAME,NAME...]}
app="$(cd "$(dirname "$0")/../app" && pwd)"
out=${2:-$app/build/screenshots}
mkdir -p "$out"
out="$(cd "$out" && pwd)"

cd "$app"
# Two runs: the screens, then the workout screens with a workout under way,
# which every other screen would otherwise show in its tab bar.
for workout in false true; do
  defines=(--dart-define=SHOTS_ONLY="${3:-}" --dart-define=SHOTS_WORKOUT=$workout --dart-define=STAGING_TIPS=false)
  if [ $workout = true ]; then
    defines+=(--dart-define=STAGING_WORKOUT=user-workout-upper --dart-define=STAGING_WORKOUT_LOGGED=3)
  fi
  SHOTS_DIR="$out" flutter drive \
    --flavor staging \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/screens_test.dart \
    "${defines[@]}" \
    -d "$udid"
done
echo "Screenshots in $out"
