#!/usr/bin/env bash
# Frees the disk space Xcode's simulators leave behind.
#
# Parallel test runs clone the destination simulator several times and never remove the
# clones. SwiftUI previews keep their own simulators too. On 29 Sep 2026 that came to 109
# clones and roughly 250 GB of "System Data".
#
# Usage: scripts/clean-simulators.sh [--wait]
#   Refuses to run while a test run is in progress, because deleting a clone under a running
#   test fails that test. --wait also waits for the deleted simulators to leave the disk, which
#   the system otherwise does in the background over several minutes.
set -euo pipefail

if pgrep -f "xcodebuild.* test( |$)|xcodebuild.*test-without-building|xctest" >/dev/null; then
    echo "A test run is in progress. Run this again when it has finished." >&2
    exit 1
fi

before=$(df -k /System/Volumes/Data | tail -1 | awk '{print $4}')

xcrun simctl --set testing shutdown all >/dev/null 2>&1 || true
xcrun simctl --set testing delete all >/dev/null 2>&1 || true
xcrun simctl --set previews delete all >/dev/null 2>&1 || true
xcrun simctl delete unavailable >/dev/null 2>&1 || true

# A deleted simulator is moved to the temporary folder as "Deleting-<id>" and removed there one
# at a time. Removing them here, several at once, is many times quicker.
find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'Deleting-*' -print0 2>/dev/null | xargs -0 -n 1 -P 6 rm -rf

if [[ "${1:-}" == --wait ]]; then
    for _ in $(seq 1 60); do
        [[ -z "$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'Deleting-*' -print -quit 2>/dev/null)" ]] && break
        sleep 5
    done
fi

after=$(df -k /System/Volumes/Data | tail -1 | awk '{print $4}')
echo "Free space: $((before / 1048576)) GB before, $((after / 1048576)) GB now."
