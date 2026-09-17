#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d /tmp/continuous-dictation-test.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -parse-as-library -module-cache-path "$test_dir/cache" \
    "$project_root/ChineseEcho/Services/AppPreferences.swift" \
    "$project_root/ChineseEcho/Services/PracticeSessionStore.swift" \
    "$project_root/ChineseEcho/Services/ReviewScheduler.swift" \
    "$project_root/ChineseEcho/Services/DictationStore.swift" \
    "$project_root/ChineseEcho/Models/VocabularyWord.swift" \
    "$project_root/ChineseEcho/Models/DictationSet.swift" \
    "$project_root/ChineseEcho/Models/DictationSetAppearance.swift" \
    "$project_root/tests/continuous_dictation.swift" \
    -o "$test_dir/continuous-dictation-test"
"$test_dir/continuous-dictation-test"
