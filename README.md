# Pi Studio / Pi Pocket — shared native session demo

Native SwiftUI for **macOS 26** (Pi Studio) and **iPhone/iPad iOS 26.1**
(Pi Pocket). The existing `pi-studio` scheme/target builds for both platforms;
select **My Mac** for a native desktop app, not Catalyst. The mobile product is
still a Simulator/local-server demo, not a remotely deployed phone controller.

One screen shows connection state, explicit Connect/Disconnect, a plain-text
transcript, message field, Send, Stop and errors. No connection opens on launch.
The approved layout is preserved in [mockups/session](mockups/session/DESIGN.md).

## Architecture

- [PiUI](Packages/PiUI/Package.swift) is a local Swift package shared by both
  platforms. It depends on PiSDK and [Flux](https://github.com/ManuelSelch/Flux),
  pinned to `00c8b43799d5acbca04127833daf28f1df2ce477` (including FluxTestStore).
- [SessionFeature](Packages/PiUI/Sources/PiUI/SessionFeature.swift) holds app-owned
  interaction state and typed reducer actions. FluxStore is the sole observable
  source of that state; drafts and action/error flags are not a second model.
- [SessionController](Packages/PiUI/Sources/PiUI/SessionController.swift) owns
  awaitable SDK effects, observation tasks and disposal, feeding Flux actions.
  Long-lived SDK observation is explicitly cancelled rather than hidden inside
  uncancellable Flux middleware tasks. Generation tokens reject obsolete results.
- [Containers](Packages/PiUI/Sources/PiUI/Containers) bridge Flux, injected
  dependencies and callbacks to presentation. Future navigation/router wiring
  belongs here or in the host shell; this single-screen slice needs no router.
- [Components](Packages/PiUI/Sources/PiUI/Components) import SwiftUI only and take
  plain display values and callbacks. They do not read stores, resolve services,
  use SDK models or perform network work. Local focus/alert state is UI-only.
- The [app shell](pi-studio/pi_studioApp.swift) owns lifetime and native windows.
  iOS backgrounding disposes local networking. macOS losing focus does not;
  closing its single window disposes the local connection.
- PiSDK owns protocol validation, request correlation, transport, authoritative
  session projections and run settlement. It does not depend on Flux or PiUI.

## Development wiring

- Verified stable toolchain: **Xcode 26.1.1 (17B100), Swift 6.2.1**.
- PiSDK checkout defaults to `~/.pi/agent/git/pi-chat/packages/pi-sdk`.
- Required SDK API baseline: `66ce80552d1757280bbdfdc8bab05f0c3ba8b88c` or later;
  this extraction was verified against pi-chat `b6fcc8865c25454315858be96ca2c76092395537`.
- Run `bash scripts/prepare.sh` **before opening Xcode in a fresh checkout or
  worktree**. It creates ignored `.dependencies/pi-sdk` wiring and resolves the
  pinned Flux dependency. Set `PI_SDK_PATH` to use a different SDK checkout.
  The SDK is local and is not fetched or updated automatically; no packages are
  published. Keep both Package.resolved files checked in.

[SessionConfiguration](Packages/PiUI/Sources/PiUI/SessionController.swift)
defaults to `ws://127.0.0.1:8787/ws` and the dedicated **server-side** directory
`/tmp/pi-studio-demo`. Create that directory and start the local v2 Pi Server
before connecting. The app does not start/install the backend or store model
credentials. Configuration is injected, not a settings screen.

Keep the backend loopback-only. Debug builds permit local networking through
[DebugInfo.plist](Configuration/DebugInfo.plist); Release has no ATS exception.
The macOS app sandbox permits outgoing network connections. No global arbitrary
loads exemption, remote-device networking, proxy or auth was added. On a physical
iPhone, loopback refers to the phone, not your Mac.

## Behavior

- Connect asks for takeover consent: initialization replaces the existing server
  controller. **Single-controller handoff is intentional**; simultaneous Studio
  and Pocket control is not required.
- Each explicit connection creates one fresh demo session. Existing runtimes are
  never attached to, aborted or closed by the app.
- Send permits one nonempty plain-text prompt while idle. Slash/bash commands,
  steering and queued messages are deliberately unsupported. Drafts clear only
  after admission, remain on rejection/unknown outcome, and are never replayed.
- SDK-owned complete projections deliver incremental text, ordered messages and
  finalized answers without duplicate drafts. Admission is not answer completion.
- Stop retains partial text and shows Stopping until authoritative settlement.
  A completed abort response means the server is idle; an accepted abort is not
  completion. Missing start/stop settlement has a bounded deadline.
- Disconnect during active/pending work warns that server work may continue.
  Disconnect retains the transcript; a new explicit connection resets it.
  Background/teardown disposal never implicitly aborts or closes server runtimes.
- Unknown mutation outcomes remain visible and disable automatic resubmission.
  Unexpected closure, malformed data, overflow, sequence gaps and unsupported
  structured questions end the connection explicitly, retaining observed text.

Disconnect does **not** close server runtimes. Clean up retained demo IDs through
Pi Chat or explicit v2 `session.close`. A lost create response may leave a runtime
behind. Avoid repeated connections without cleanup.

## Test pipeline

[.pi/pipeline.json](.pi/pipeline.json) configures once-per-worktree preparation and
seven independent suites. Only fast `piui` tests opt into after-agent execution;
UI automation is manual because it takes control of the Simulator/desktop.

Equivalent commands after preparation:

```sh
bash scripts/prepare.sh
bash scripts/test-package.sh
bash scripts/test-app.sh ios unit
bash scripts/test-app.sh ios ui
bash scripts/test-app.sh macos unit
bash scripts/test-app.sh macos ui
bash scripts/test-app.sh ios release
bash scripts/test-app.sh macos release
```

Native suites use a checked-in shared scheme, per-platform derived data,
serial execution, and no development backend. Build products and test-process
working directories live outside the protected Documents checkout, under
`~/Library/Developer/Xcode/DerivedData/PiStudio-<worktree-hash>`; override with
`PI_STUDIO_BUILD_ROOT` using another non-protected location. This avoids test
runners requesting Documents-folder access just to load their own products.
The app itself needs no access to local Documents files. Do not grant Full Disk
Access as a workaround. Ad-hoc signing can also invalidate TCC approvals between
builds; use stable Apple Development signing if future app features genuinely
need protected permissions. iOS defaults to the **iPhone 17**
Simulator; override `PI_STUDIO_TEST_DESTINATION` for another installed device.
macOS uses ad-hoc local signing (no Apple account) so UI-test runners can launch;
iOS Simulator builds disable signing. Functional iOS UI tests explicitly select
portrait rather than inheriting rotation from launch-appearance tests.

- PiUI: **12 named tests** (one with two cases), including FluxTestStore reducer
  transitions, draft admission/retention, duplicate guards, stale callbacks,
  setup/pending-send disconnect, connection errors and deallocation disposal.
- The same **nine controller tests** also compile/run inside the iOS and macOS
  native unit-test targets; their source is shared, not copied.
- Both platforms run five functional UI tests (consent, two turns/Stop,
  active disconnect, rejected send, unknown outcome), plus launch/appearance
  screenshot tests. Debug-only injected connections are never selected by normal
  app launches; tests use public SDK projections, not a second wire protocol.
- Debug/unit/UI and Release builds pass on both platforms.

### Explicit isolated transport acceptance

Normal suites skip the opt-in network test. To exercise **PiUI + Flux + actual
URLSession/Pi Server transport** without model credentials:

```sh
bash scripts/test-simulator-loopback.sh ios
bash scripts/test-simulator-loopback.sh macos
```

This requires pi-chat's installed Node/tsx dependencies and built SDK dist
(`npm ci` and `npm run build:sdk` there). Override `PI_CHAT_CHECKOUT` if needed.
The script owns an ephemeral-loopback fake-runtime server with temporary metadata
and empty history. It verifies streaming, a second turn, Stop/retained text and
disconnect through SessionController, then verifies exactly one retained runtime
is explicitly closed and the test-owned server is stopped. It never points to the
user's development server. Failure logs are retained in a temporary directory.

## Limitations

Controlled **real-model Pi acceptance is still outstanding**; fake-runtime tests
are not model-provider proof. Dialog answers, Markdown, tool/thinking rendering,
session browsing/opening, public close APIs, reconnect/gap recovery, optional
extension UI and secure remote access remain out of scope. Sequence gaps fail
explicitly instead of attempting recovery. This remains a subset of the parent
SDK Swift vertical slice, not full parity or a complete Pi Chat replacement.
