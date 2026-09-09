#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d /tmp/speech-recovery-test.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -parse-as-library -module-cache-path "$test_dir/cache" \
    "$project_root/ChineseEcho/Services/SpeechAudioEngine.swift" \
    "$project_root/tests/speech_recovery.swift" \
    -o "$test_dir/speech-recovery-test"
"$test_dir/speech-recovery-test"
