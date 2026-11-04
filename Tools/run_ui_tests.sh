#!/bin/sh
# Runs the UI tests on a simulator. Usage: Tools/run_ui_tests.sh [simulator-udid] [extra xcodebuild args]
set -u
cd "$(dirname "$0")/.."
SIM="${1:-$(xcrun simctl list devices booted | grep -Eo '[0-9A-F-]{36}' | head -1)}"
[ $# -gt 0 ] && shift
OUT="${BOLIKEY_TEST_OUT:-build/uitest}"
rm -rf "$OUT/result.xcresult"
mkdir -p "$OUT"
xcodebuild test -project BoliKey.xcodeproj -scheme BoliKey -destination "platform=iOS Simulator,id=$SIM" \
  -derivedDataPath "$OUT/dd" -resultBundlePath "$OUT/result.xcresult" "$@" > "$OUT/test.log" 2>&1
STATUS=$?
grep -E "error:|Test Case .* (passed|failed)|TEST (SUCCEEDED|FAILED)|Executed [0-9]+ test" "$OUT/test.log" | sed -E 's/^.*UITests\///' | cut -c1-220
exit $STATUS
