#!/bin/bash
# Prepare local Router and resolve released dependencies; never start a server.
set -euo pipefail
source "$(dirname "$0")/build-paths.sh"
# Resolve relative overrides from the caller's working directory, before changing it.
router_path="${PI_ROUTER_PATH:-${HOME}/Documents/A_Personal/50 Coding/52 iOS/52.01 Packages/router-modernized}"
if [[ ! -f "$router_path/Package.swift" ]]; then
  echo "Router checkout unavailable: $router_path. Set PI_ROUTER_PATH to the modernized Router checkout." >&2
  exit 1
fi
router_path=$(cd "$router_path" && pwd -P)
router_link="$project_root/.dependencies/router"
if [[ -e "$router_link" && ! -L "$router_link" ]]; then
  echo "Refusing to replace non-symlink: $router_link" >&2
  exit 1
fi
mkdir -p "$project_root/.dependencies"
ln -sfn "$router_path" "$router_link"
cd "$build_root"
swift package --package-path "$project_root/Packages/PiUI" --scratch-path "$build_root/swiftpm" resolve
