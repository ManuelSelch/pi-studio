# Pi Studio — minimal streaming demo

Native SwiftUI on the existing **iPhone/iPad iOS 26.1 Simulator target**.
One screen shows connection state, explicit Connect/Disconnect, a plain-text
transcript, message field, Send, Stop and errors. No connection opens on launch.
The approved design is preserved in [mockups/session](mockups/session/DESIGN.md);
its preview server has been stopped.

## Development wiring

- Stable toolchain verified: **Xcode 26.1.1 (17B100), Swift 6.2.1**.
- Explicit local SwiftPM product/module: **PiSDK**.
- SDK checkout: `~/.pi/agent/git/pi-chat/packages/pi-sdk`.
- Required SDK revision: **66ce80552d1757280bbdfdc8bab05f0c3ba8b88c**.
- The package reference is relative to this checkout. Update it if either repo
  moves. Nothing is published or pushed.

[DemoConfiguration](pi-studio/DemoSessionModel.swift) defaults to
`ws://localhost:8787/ws` and the dedicated **server-side** directory
`/tmp/pi-studio-demo`. Create that directory before connecting. Run a local v2
Pi Server with an available model; the app does not start/install the backend or
store model credentials. Configuration is injected, not a settings screen.

Keep the backend loopback-only. Debug builds permit local networking through
[DebugInfo.plist](Configuration/DebugInfo.plist); Release has no exception. No
global arbitrary-load exemption, remote-device networking, proxy or auth was
added. The simulator transport was verified against an ephemeral host server.

## Behavior

- Connect asks for takeover consent: initialization replaces the existing server
  controller. Do not casually connect to a backend being used by another client.
- Each explicit connection creates one fresh demo session. Existing runtimes are
  never attached to, aborted or closed by the app.
- Send permits one nonempty plain-text prompt while idle. Slash/bash commands,
  steering and queued messages are deliberately unsupported. Drafts clear only
  after admission, remain on rejection/unknown outcome, and are never replayed.
- SDK-owned complete projections deliver incremental text, ordered messages and
  finalized answers without duplicate drafts. Admission is not answer completion.
- Stop keeps the partial answer and shows Stopping until authoritative settlement.
  A completed abort response means the server is already idle; an accepted abort
  is not completion. Missing start/stop settlement has a bounded deadline.
- Disconnect during active/pending work warns that the server may continue.
  Disconnect retains the displayed transcript; a new explicit connection resets
  it. Going into the background disposes local networking rather than implying
  background execution support. No implicit abort/close occurs on teardown.
- Unknown mutation outcomes are visible and disable automatic resubmission.
  Unexpected closure, malformed data, overflow, sequence gaps and unsupported
  structured questions end the connection explicitly, retaining observed text.

Disconnect does **not** close server runtimes. Clean up retained demo IDs through
Pi Chat or explicit v2 `session.close` requests. A lost create response may have
left a runtime behind. Avoid repeated connections without cleanup.

## Verification

From this checkout:

```sh
swift test --package-path ../../../../../.pi/agent/git/pi-chat/packages/pi-sdk
xcodebuild -project pi-studio.xcodeproj -scheme pi-studio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO
bash scripts/test-simulator-loopback.sh
```

The loopback script requires pi-chat's installed Node/tsx dependencies and built
SDK dist (`npm install`, `npm run build:sdk` there). Override `PI_CHAT_CHECKOUT`
if needed and `PI_STUDIO_TEST_DESTINATION` for another simulator. It starts only
an isolated fake-runtime server on an ephemeral loopback port with temporary
metadata and empty history. It runs the opt-in simulator WebSocket test and
verifies that exactly one retained runtime is explicitly closed during cleanup.
The opt-in test is skipped during normal test runs, never silently pointed at the
user's development backend.

Passed for this revision:

- SwiftPM: six existing generation probes + **20 named SDK tests**, including
  parameterized failures, two sequential turns, incremental/final text, Stop,
  stopped-prefix retention across snapshots, stale/duplicate sequences, malformed
  frames, unsupported questions, gap/overload failure, bounded settlement waits,
  rejection/unknown outcomes, slow observers, cancellation and disconnect.
- Actual Pi Server with fake runtime on macOS **and iOS Simulator**: connect,
  “Say hello”, incremental text, completion, second turn, Stop with partial text,
  disconnect retention, explicit runtime cleanup and owned-server shutdown.
- Six app-model test declarations (one with two cases), five native UI tests
  covering takeover consent, two turns/Stop, active disconnect warning, definite
  rejection and uncertain-send draft retention, plus existing launch tests.
- TypeScript SDK: **154 tests** pass.
- Native disconnected-state screenshot inspected against the approved layout.
  Native controls, dark mode, safe areas and keyboard follow SwiftUI rather than
  browser CSS. No mockup-only state selector ships in the app.
- `git diff --check` in both repositories.

UI tests use a Debug-only injected connection with public SDK projections; normal
launches use the real SDK. They do not require credentials or a live model.

## Limitations

Controlled **real-model Pi acceptance is not yet run**; fake-runtime transport
acceptance is not presented as model-provider proof. Dialog answers, Markdown,
tool-detail/thinking rendering, session browsing/opening, public close APIs,
reconnect/snapshot-gap recovery, optional extension UI and remote access remain
out of scope. Sequence gaps fail explicitly instead of attempting recovery.
This is still a subset of the parent SDK Swift vertical slice, not full parity.
