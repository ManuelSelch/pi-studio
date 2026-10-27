#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/build-paths.sh"
cd "$build_root"
args=(--package-path "$project_root/Packages/PiUI" --scratch-path "$build_root/swiftpm")
if [[ "${PI_STUDIO_COVERAGE:-0}" == 1 ]]; then
  swift test "${args[@]}" --enable-code-coverage
  bin_path=$(swift build "${args[@]}" --show-bin-path)
  coverage_dir="$project_root/.build/coverage"
  mkdir -p "$coverage_dir"
  xcrun llvm-cov export -format=lcov \
    -instr-profile="$bin_path/codecov/default.profdata" \
    "$bin_path/PiUIPackageTests.xctest/Contents/MacOS/PiUIPackageTests" \
    > "$coverage_dir/piui.lcov"
  python3 "$project_root/scripts/sonar-coverage.py" "$project_root" \
    "$coverage_dir/piui.lcov" "$coverage_dir/sonar.xml"
else
  swift test "${args[@]}"
fi
