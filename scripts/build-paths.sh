#!/bin/bash
# Source this file. Keep executable test products AND their working directory
# outside Documents/Desktop/Downloads so they do not need Files & Folders access.
project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
worktree_id=$(printf '%s' "$project_root" | shasum -a 256 | cut -c 1-12)
build_root="${PI_STUDIO_BUILD_ROOT:-${HOME}/Library/Developer/Xcode/DerivedData/PiStudio-${worktree_id}}"
mkdir -p "$build_root"
build_root=$(cd "$build_root" && pwd -P)
