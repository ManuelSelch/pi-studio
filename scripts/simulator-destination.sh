#!/bin/bash
# Source after build-paths.sh. Each worktree gets its own installed app/runner,
# not just separate DerivedData; concurrent worktrees share bundle identifiers.
select_simulator_destination() {
  if [[ -n "${PI_STUDIO_TEST_DESTINATION:-}" ]]; then
    printf '%s\n' "$PI_STUDIO_TEST_DESTINATION"
    return
  fi
  local name="PiStudio-${worktree_id}" selection kind value
  selection=$(xcrun simctl list devices available --json | python3 -c '
import json, sys
name = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
for runtime, entries in devices.items():
    for device in entries:
        if device["name"] == name:
            print("device " + device["udid"])
            sys.exit(0)
for runtime, entries in devices.items():
    if any(device["name"] == "iPhone 17" for device in entries):
        print("runtime " + runtime)
        sys.exit(0)
sys.exit("Install an iPhone 17 Simulator or set PI_STUDIO_TEST_DESTINATION.")
' "$name") || return
  read -r kind value <<< "$selection"
  if [[ "$kind" == runtime ]]; then
    value=$(xcrun simctl create "$name" com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$value") || return
  fi
  printf 'platform=iOS Simulator,id=%s\n' "$value"
}
