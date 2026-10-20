#!/bin/bash
# Resolve local SDK wiring for this checkout/worktree; never start a server.
set -euo pipefail
source "$(dirname "$0")/build-paths.sh"
cd "$project_root"
sdk="${PI_SDK_PATH:-${HOME}/.pi/agent/git/pi-chat/packages/pi-sdk}"
[[ -f "$sdk/Package.swift" ]] || { echo "Set PI_SDK_PATH to your PiSDK checkout." >&2; exit 1; }
sdk=$(cd "$sdk" && pwd -P)
mkdir -p .dependencies
if [[ -e .dependencies/pi-sdk && ! -L .dependencies/pi-sdk ]]; then
  echo '.dependencies/pi-sdk must be a symlink, not a directory.' >&2; exit 1
fi
ln -sfn "$sdk" .dependencies/pi-sdk
cd "$build_root"
swift package --package-path "$project_root/Packages/PiUI" --scratch-path "$build_root/swiftpm" resolve
