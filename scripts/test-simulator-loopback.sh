#!/bin/bash
# Owns only an ephemeral fake-runtime Pi Server; never uses the live backend.
set -euo pipefail
cd "$(dirname "$0")/.."
server_repo="${PI_CHAT_CHECKOUT:-${HOME}/.pi/agent/git/pi-chat}"
directory=$(mktemp -d -t pi-studio-simulator)
pid=""
fixture_directory=""
cleanup() {
  local result=$?
  set +e
  trap - EXIT
  if [[ -n "$pid" ]]; then
    kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" || result=1
  fi
  if [[ "$result" == 0 ]]; then
    python3 - "$fixture_directory/cleanup.json" <<'PY'
import json, sys
from pathlib import Path
result = json.loads(Path(sys.argv[1]).read_text())
assert result == {"created": 1, "retained": 1, "closed": 1}, result
print("Verified one test-owned runtime retained on disconnect and explicitly closed during cleanup.")
PY
    result=$?
  fi
  if [[ "$result" == 0 ]]; then
    rm -rf "$directory" "$fixture_directory"
  else
    echo "Failure logs retained in $directory" >&2
  fi
  exit "$result"
}
trap cleanup EXIT
(cd "$server_repo" && exec node --import tsx test/swift-integration/fixtures/loopback-server.ts) > "$directory/server.log" 2>&1 &
pid=$!
for _ in $(seq 1 100); do
  if python3 - "$directory/server.log" "$directory/ready.json" <<'PY'
import json, sys
from pathlib import Path
for line in Path(sys.argv[1]).read_text().splitlines(keepends=True):
    if line.endswith("\n") and line.startswith("PI_FIXTURE_READY "):
        record = json.loads(line.removeprefix("PI_FIXTURE_READY "))
        path = Path(record["directory"])
        assert path.is_absolute() and path.name.startswith("pi-swift-fixture-") and path.is_dir()
        assert record["endpoint"].startswith("ws://127.0.0.1:")
        Path(sys.argv[2]).write_text(json.dumps(record))
        sys.exit(0)
sys.exit(1)
PY
  then break; fi
  kill -0 "$pid" 2>/dev/null || { echo "Fixture exited; inspect $directory/server.log" >&2; exit 1; }
  sleep 0.1
done
[[ -f "$directory/ready.json" ]] || { echo "Fixture startup timed out" >&2; exit 1; }
endpoint=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["endpoint"])' "$directory/ready.json")
fixture_directory=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["directory"])' "$directory/ready.json")
echo "Testing native PiUI/Flux with URLSession against isolated $endpoint"
TEST_RUNNER_PI_STUDIO_TEST_ENDPOINT="$endpoint" \
TEST_RUNNER_PI_STUDIO_TEST_PROJECT="$fixture_directory" \
bash scripts/test-app.sh "${1:-ios}" unit
