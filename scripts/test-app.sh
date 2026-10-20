#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/build-paths.sh"
cd "$build_root"
platform="${1:?Pass ios or macos}"
suite="${2:?Pass unit, ui, or release}"
case "$platform" in
  ios) destination="${PI_STUDIO_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17}" ;;
  macos) destination='platform=macOS' ;;
  *) echo "Unknown platform: $platform" >&2; exit 2 ;;
esac
args=(-project "$project_root/pi-studio.xcodeproj" -scheme pi-studio -destination "$destination"
      -derivedDataPath "$build_root/xcode-$platform" -parallel-testing-enabled NO)
if [[ "$platform" == macos ]]; then
  # macOS UI-test runners must be signed to bootstrap. Ad-hoc signing needs no account.
  args+=(CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=)
else
  args+=(CODE_SIGNING_ALLOWED=NO)
fi
case "$suite" in
  unit) xcodebuild "${args[@]}" -only-testing:pi-studioTests test ;;
  ui) xcodebuild "${args[@]}" -only-testing:pi-studioUITests test ;;
  release) xcodebuild "${args[@]}" -configuration Release build ;;
  *) echo "Unknown suite: $suite" >&2; exit 2 ;;
esac
