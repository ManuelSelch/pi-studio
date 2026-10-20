#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/build-paths.sh"
cd "$build_root"
swift test --package-path "$project_root/Packages/PiUI" --scratch-path "$build_root/swiftpm"
