#!/bin/bash
# Owns only an ephemeral fake-runtime Pi Server; never uses the live backend.
set -euo pipefail
cd "$(dirname "$0")/.."
server_repo="${PI_CHAT_CHECKOUT:-../../../../../.pi/agent/git/pi-chat}"
directory=$(mktemp -d -t pi-studio-simulator)
pid=""
cleanup() {
  local result=$?
  set +e
  trap - EXIT
  if [[ -n "$pid" ]]; then
    kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" || result=1
  fi
  if [[ "$result" == 0 ]]; then
    python3 - "$directory/cleanup.json" <<'PY'
import json, sys
from pathlib import Path
result = json.loads(Path(sys.argv[1]).read_text())
assert result == {"created": 1, "retained": 1, "closed": 1}, result
print("Verified one test-owned runtime retained on disconnect and explicitly closed during cleanup.")
PY
    result=$?
  fi
  if [[ "$result" == 0 ]]; then
    rm -rf "$directory"
  else
    echo "Failure logs retained in $directory" >&2
  fi
  exit "$result"
}
trap cleanup EXIT
(cd "$server_repo" && exec node --import tsx packages/pi-sdk/Tests/Fixtures/loopback-server.ts "$directory") > "$directory/server.log" 2>&1 &
pid=$!
for _ in $(seq 1 100); do
  [[ -f "$directory/endpoint" ]] && break
  kill -0 "$pid" 2>/dev/null || { echo "Fixture exited; inspect $directory/server.log" >&2; exit 1; }
  sleep 0.1
done
[[ -f "$directory/endpoint" ]] || { echo "Fixture startup timed out" >&2; exit 1; }
endpoint=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).read_text())' "$directory/endpoint")
echo "Testing iOS URLSession transport against isolated $endpoint"
TEST_RUNNER_PI_STUDIO_TEST_ENDPOINT="$endpoint" \
TEST_RUNNER_PI_STUDIO_TEST_PROJECT="$directory" \
xcodebuild -project pi-studio.xcodeproj -scheme pi-studio \
  -destination "${PI_STUDIO_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17}" \
  -parallel-testing-enabled NO -only-testing:pi-studioTests test CODE_SIGNING_ALLOWED=NO
