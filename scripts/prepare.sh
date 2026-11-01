#!/bin/bash
# Link the local PiSDK and resolve remote dependencies; never start a server.
set -euo pipefail
source "$(dirname "$0")/build-paths.sh"
default_sdk="${HOME}/Documents/A_Personal/40 Projekte/47 Agents/Pi Agent/pi-sdk-swift"
sdk_source="${PI_SDK_SWIFT_PATH:-$default_sdk}"
if [[ ! -f "$sdk_source/Package.swift" ]]; then
  echo "Swift PiSDK package not found at: $sdk_source" >&2
  exit 1
fi
sdk_source=$(cd "$sdk_source" && pwd -P)
mkdir -p "$project_root/.dependencies"
sdk_link="$project_root/.dependencies/pi-sdk-swift"
if [[ -e "$sdk_link" && ! -L "$sdk_link" ]]; then
  echo "Refusing to replace non-symlink dependency path: $sdk_link" >&2
  exit 1
fi
ln -sfn "$sdk_source" "$sdk_link"
cd "$build_root"
swift package --package-path "$project_root/Packages/PiUI" --scratch-path "$build_root/swiftpm" resolve
