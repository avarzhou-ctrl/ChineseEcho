#!/bin/bash

set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 /path/to/ChineseEcho.app VERSION OUTPUT_DIRECTORY" >&2
    exit 64
fi

source_app="$1"
version="$2"
output_directory="$3"
script_directory="$(cd "$(dirname "$0")" && pwd)"
entitlements="$script_directory/ChineseEcho.release.entitlements"

if [[ ! -d "$source_app" || ! -f "$source_app/Contents/Info.plist" ]]; then
    echo "Expected an exported ChineseEcho.app bundle: $source_app" >&2
    exit 66
fi

if [[ ! "$version" =~ ^[0-9]+([.][0-9]+)*$ ]]; then
    echo "Version must contain only dot-separated numbers: $version" >&2
    exit 64
fi

staging_root="$(mktemp -d /tmp/chineseecho-release.XXXXXX)"
trap 'rm -rf "$staging_root"' EXIT

staged_app="$staging_root/ChineseEcho.app"
archive_name="ChineseEcho-${version}-macOS.zip"
archive_path="$output_directory/$archive_name"
checksum_path="$archive_path.sha256"

mkdir -p "$output_directory"
cp -R "$source_app" "$staged_app"

# Exported unsigned builds retain only linker signatures, which do not seal the
# app's resources. Clear inherited metadata and sign nested code before the app.
xattr -cr "$staged_app"
while IFS= read -r -d '' nested_code; do
    codesign --force --sign - "$nested_code"
done < <(find "$staged_app/Contents/Frameworks" -type f -name '*.dylib' -print0 2>/dev/null)

codesign \
    --force \
    --sign - \
    --entitlements "$entitlements" \
    "$staged_app"

codesign --verify --deep --strict --verbose=2 "$staged_app"

rm -f "$archive_path" "$checksum_path"
ditto -c -k --norsrc --noextattr --keepParent "$staged_app" "$archive_path"

(
    cd "$output_directory"
    shasum -a 256 "$archive_name" > "$(basename "$checksum_path")"
)

echo "Created $archive_path"
echo "Created $checksum_path"
