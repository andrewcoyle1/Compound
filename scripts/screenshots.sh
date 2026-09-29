#!/usr/bin/env bash
# Screenshot deck: launches the Mock build on every STARTSCREEN_* argument in
# AppViewForUITesting.swift, in light and dark, and writes Screenshots/<ARG>-<light|dark>.jpg
# plus a contact sheet at Screenshots/index.html.
#
# Usage: scripts/screenshots.sh [--diff] [simulator-udid]
#   With no UDID, the first available iPhone on the newest iOS runtime is used.
#   SKIP_BUILD=1 reuses the last build in $HOME/.dd-screenshots.
#   --diff runs scripts/screenshots-diff.py against the committed deck after capture and exits
#   with its status (non-zero when any screen changed).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$HOME/.dd-screenshots"
BUNDLE_ID="com.andrewcoyle.DialedIn.mock"
OUT="$ROOT/Screenshots"
SOURCE="$ROOT/DialedIn/Root/EntryPoints/AppViewForUITesting.swift"
START=$(date +%s)

DIFF=0
if [[ "${1:-}" == --diff ]]; then DIFF=1; shift; fi
UDID="${1:-}"
if [[ -z "$UDID" ]]; then
    UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
runtimes = json.load(sys.stdin)["devices"]
ios = sorted((k for k in runtimes if "iOS" in k), key=lambda k: [int(p) for p in k.rsplit("iOS-", 1)[1].split("-")])
for runtime in reversed(ios):
    phones = [d for d in runtimes[runtime] if d["name"].startswith("iPhone")]
    if phones:
        print(phones[0]["udid"]); break')
fi
[[ -n "$UDID" ]] || { echo "No iPhone simulator found" >&2; exit 1; }
echo "Simulator: $UDID"

# Read at run time so arguments added by other branches are covered without editing this script.
ARGS=()
while IFS= read -r arg; do ARGS+=("$arg"); done < <(grep -o '"STARTSCREEN_[A-Z0-9_]*"' "$SOURCE" | tr -d '"' | awk '!seen[$0]++')
echo "${#ARGS[@]} screens"

if [[ "${SKIP_BUILD:-0}" != 1 ]]; then
    xcodebuild build -project "$ROOT/DialedIn.xcodeproj" -scheme 'DialedIn - Mock' \
        -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" -quiet
fi
APP=$(ls -d "$DERIVED"/Build/Products/Mock-iphonesimulator/*.app | grep -v WorkoutSessionActivity | head -1)

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP"
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true

mkdir -p "$OUT"
rm -f "$OUT"/STARTSCREEN_*
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"; xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true' EXIT

# A frame with nothing but the status bar is ~70 KB as PNG; any real screen is several times that.
BLANK_BYTES=150000
shoot() { xcrun simctl io "$UDID" screenshot --type=png "$1" >/dev/null 2>&1; }

for appearance in light dark; do
    xcrun simctl ui "$UDID" appearance "$appearance"
    for arg in "${ARGS[@]}"; do
        xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" UI_TESTING SIGNED_IN "$arg" >/dev/null
        # Wait for the screen. The UI-testing root shows a blank frame while it signs in to the
        # mock scenario, then presents the screen as a cover. Anything before the blank frame is
        # the previous launch, so: wait (up to 10 s) for a blank frame, then poll (up to 6 s)
        # until a non-blank frame holds still for two captures in a row.
        deadline=$(( $(date +%s) + 10 ))
        while (( $(date +%s) < deadline )); do
            shoot "$TMP/prev.png"
            (( $(stat -f %z "$TMP/prev.png") < BLANK_BYTES )) && break
        done
        deadline=$(( $(date +%s) + 6 ))
        while (( $(date +%s) < deadline )); do
            sleep 0.3
            shoot "$TMP/cur.png"
            if (( $(stat -f %z "$TMP/cur.png") >= BLANK_BYTES )) && cmp -s "$TMP/prev.png" "$TMP/cur.png"; then break; fi
            mv "$TMP/cur.png" "$TMP/prev.png"
        done
        sips -s format jpeg -s formatOptions 70 "$TMP/prev.png" --out "$OUT/$arg-$appearance.jpg" >/dev/null
        echo "  $arg ($appearance)"
    done
done

xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true
python3 "$ROOT/scripts/contact-sheet.py" "$OUT"
echo "Done in $(( $(date +%s) - START ))s, $(du -sh "$OUT" | cut -f1) in $OUT"
(( DIFF )) && exec python3 "$ROOT/scripts/screenshots-diff.py"
exit 0
