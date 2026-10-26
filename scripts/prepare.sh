#!/bin/bash
# Resolve released dependencies; never start a server.
set -euo pipefail
source "$(dirname "$0")/build-paths.sh"
cd "$build_root"
swift package --package-path "$project_root/Packages/PiUI" --scratch-path "$build_root/swiftpm" resolve
