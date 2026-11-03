#!/bin/bash
# Source after build-paths.sh. Prefer a simulator that already exists so runs do
# not pay to cold-boot a brand-new device. Concurrent worktrees share bundle
# identifiers, so locally a worktree still gets its own device; CI runs one
# worktree per ephemeral runner and reuses the preinstalled iPhone 17 directly
# instead of creating one. Set PI_STUDIO_TEST_DESTINATION to override.
select_simulator_destination() {
  if [[ -n "${PI_STUDIO_TEST_DESTINATION:-}" ]]; then
    printf '%s\n' "$PI_STUDIO_TEST_DESTINATION"
    return
  fi
  local name="PiStudio-${worktree_id}" selection kind value
  selection=$(xcrun simctl list devices available --json | python3 -c '
import json, sys
name, prefer_preinstalled = sys.argv[1], sys.argv[2] == "1"
devices = json.load(sys.stdin)["devices"]
by_name = {}
for entries in devices.values():
    for device in entries:
        by_name.setdefault(device["name"], device["udid"])
if name in by_name:
    print("device " + by_name[name])
    sys.exit(0)
if prefer_preinstalled and "iPhone 17" in by_name:
    print("device " + by_name["iPhone 17"])
    sys.exit(0)
for runtime, entries in devices.items():
    if any(device["name"] == "iPhone 17" for device in entries):
        print("runtime " + runtime)
        sys.exit(0)
sys.exit("Install an iPhone 17 Simulator or set PI_STUDIO_TEST_DESTINATION.")
' "$name" "${CI:+1}") || return
  read -r kind value <<< "$selection"
  if [[ "$kind" == runtime ]]; then
    value=$(xcrun simctl create "$name" com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$value") || return
  fi
  printf 'platform=iOS Simulator,id=%s\n' "$value"
}

# Start the destination booting without blocking. xcodebuild waits for the
# device while it compiles, so boot time overlaps the build instead of delaying
# the first test; later suites reuse the same booted device.
boot_simulator_background() {
  local udid
  case "$1" in
    *id=*) udid="${1##*id=}" ;;
    *) return 0 ;;
  esac
  [[ -n "$udid" ]] || return 0
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 &
}
