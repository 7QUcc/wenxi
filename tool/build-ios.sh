#!/usr/bin/env bash
# Build an unsigned iOS IPA (macOS with Xcode, Go 1.24.7 and Flutter 3.41.4).
# Usage: tool/build-ios.sh [build-config.json]
# Sign the result yourself (Apple ID / AltStore / SideStore / TrollStore).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
config="${1:-$root/config/build.community.json}"
mobile_version='v0.0.0-20250911085028-6912353760cf'
tools="$root/native/.tools-ios"
framework="$root/ios/AsterLinkNative/Frameworks/Gopeed.xcframework"

export GOTOOLCHAIN=go1.24.7
# gomobile generates a separate module that also needs the pinned x/mobile bind runtime.
export GOFLAGS=-mod=mod
export GOBIN="$tools"
export PATH="$tools:$PATH"

mkdir -p "$tools"
for tool in gomobile gobind; do
  if ! go version -m "$tools/$tool" 2>/dev/null | grep -q "$mobile_version"; then
    go install "golang.org/x/mobile/cmd/${tool}@${mobile_version}"
  fi
done

if [[ ! -d "$framework" || -n "${ASTERLINK_REBUILD_NATIVE:-}" ]]; then
  rm -rf "$framework"
  mkdir -p "$(dirname "$framework")"
  (
    cd "$root/native/gopeed"
    gomobile bind -tags nosqlite -trimpath \
      -ldflags '-w -s -checklinkname=0 -X github.com/GopeedLab/gopeed/pkg/base.Version=1.8.1' \
      -target=ios -iosversion 15.0 -o "$framework" ./bind/mobilecore
  )
fi

defines=()
while IFS= read -r line; do defines+=("$line"); done < <(python3 - "$config" <<'EOF'
import json, sys
s = json.load(open(sys.argv[1], encoding='utf-8'))
print(f"--dart-define=ASTERLINK_ANNOUNCEMENTS_URL={s.get('announcementsUrl', '')}")
print(f"--dart-define=ASTERLINK_CONTROL_ENABLED={str(bool(s.get('controlEnabled'))).lower()}")
print(f"--dart-define=ASTERLINK_CONTROL_URL={s.get('controlUrl', '')}")
print(f"--dart-define=ASTERLINK_GITHUB_REPO={s.get('githubRepository', '')}")
EOF
)
for file in baidu-api cloud-command parser-hub; do
  path="$root/.local/$file.defines.json"
  [[ -f "$path" ]] && defines+=("--dart-define-from-file=$path")
done

cd "$root"
flutter pub get
flutter build ios --release --no-codesign "${defines[@]}"

output="$root/build/ios/ipa"
rm -rf "$output/Payload"
mkdir -p "$output/Payload"
cp -R "$root/build/ios/iphoneos/Runner.app" "$output/Payload/"
version="$(sed -n 's/^version: *\([^+]*\).*/\1/p' "$root/pubspec.yaml")"
ipa="$output/AsterLink-$version-unsigned.ipa"
rm -f "$ipa"
(cd "$output" && zip -qry "$ipa" Payload)
rm -rf "$output/Payload"
echo "$ipa"
