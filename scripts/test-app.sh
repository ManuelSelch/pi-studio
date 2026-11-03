#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/build-paths.sh"
cd "$build_root"
platform="${1:?Pass ios or macos}"
suite="${2:?Pass unit, ui, or release}"
case "$platform" in
  ios)
    source "$project_root/scripts/simulator-destination.sh"
    destination=$(select_simulator_destination)
    ;;
  macos) destination='platform=macOS' ;;
  *) echo "Unknown platform: $platform" >&2; exit 2 ;;
esac
args=(-project "$project_root/pi-studio.xcodeproj" -scheme pi-studio -destination "$destination"
      -derivedDataPath "$build_root/xcode-$platform" -parallel-testing-enabled NO)
# CI opts in because its ephemeral runner cannot approve the Equatable compiler macro interactively.
if [[ "${PI_STUDIO_SKIP_MACRO_VALIDATION:-0}" == 1 ]]; then
  args+=(-skipMacroValidation)
fi
if [[ "$platform" == macos ]]; then
  # macOS UI-test runners must be signed to bootstrap. Ad-hoc signing needs no account.
  args+=(CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=)
else
  args+=(CODE_SIGNING_ALLOWED=NO)
  # Start the shared simulator booting now so it overlaps the build instead of
  # delaying the first test; later suites reuse the same booted device.
  [[ "$suite" == release ]] || boot_simulator_background "$destination"
fi
case "$suite" in
  unit) test_target=pi-studioTests ;;
  ui) test_target=pi-studioUITests ;;
  release) test_target= ;;
  *) echo "Unknown suite: $suite" >&2; exit 2 ;;
esac
if [[ "$suite" == release ]]; then
  # Shippability compile check only: the host architecture is enough, so skip
  # the unused universal slice. ONLY_ACTIVE_ARCH does not reach SwiftPM package
  # targets (swift-syntax still built both slices), so set ARCHS explicitly.
  xcodebuild "${args[@]}" -configuration Release ARCHS="$(uname -m)" build
else
  # Build only this suite's test bundle, then run it without rebuilding.
  xcodebuild "${args[@]}" -only-testing:"$test_target" build-for-testing
  xcodebuild "${args[@]}" -only-testing:"$test_target" test-without-building
fi
