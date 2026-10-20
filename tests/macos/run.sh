#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/CavalryWheelTests.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM
# Keep the actual production view/event handlers, omitting only the application launch entry.
cat "$ROOT/native/macos/UIDispatch.swift" > "$TEST_DIR/main.swift"
sed '/^let app=NSApplication.shared/,$d' "$ROOT/native/macos/CavalryWheel.swift" >> "$TEST_DIR/main.swift"
cat "$ROOT/tests/macos/WheelBehaviorTests.swift" "$ROOT/tests/macos/UIDispatchTests.swift" >> "$TEST_DIR/main.swift"
/usr/bin/xcrun swiftc -O "$TEST_DIR/main.swift" -framework AppKit -framework ApplicationServices -o "$TEST_DIR/wheel-tests"
"$TEST_DIR/wheel-tests"
