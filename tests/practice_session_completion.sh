#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d /tmp/practice-session-test.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -parse-as-library \
    "$project_root/ChineseEcho/Services/PracticeSessionStore.swift" \
    "$project_root/tests/practice_session_completion.swift" \
    -o "$test_dir/practice-session-test"
"$test_dir/practice-session-test"
