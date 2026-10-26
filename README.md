# Pi Studio / Pi Pocket — shared native session demo

Native SwiftUI for **macOS 26** (Pi Studio) and **iPhone/iPad iOS 26.1**
(Pi Pocket). The existing `pi-studio` scheme/target builds for both platforms;
select **My Mac** for a native desktop app, not Catalyst. The mobile product is
still a Simulator/local-server demo, not a remotely deployed phone controller.

One screen shows connection state, explicit Connect/Disconnect, a plain-text
transcript, multiline message field, icon-only ↑ Send and errors. macOS Esc stops
an active run; iOS replaces Send with a stop icon while running. No connection
opens on launch. The approved layouts are preserved in
[mockups/session](mockups/session/DESIGN.md), [mockups/settings](mockups/settings/DESIGN.md)
and [mockups/multiline-composer](mockups/multiline-composer/DESIGN.md).

## App icons

Both platforms use Pi Chat's black π on white (`public/apple-touch-icon.png`
in the Pi Chat repository). macOS uses the native Icon Composer document
`pi-studio/StudioIcon.icon`: a full-size solid white background and a separate
transparent black π layer, without a baked-in tile or corner mask. Open this
file in Icon Composer to edit the composition. Debug and Release select
`StudioIcon` on macOS, avoiding Tahoe's gray legacy-icon wrapper.
iOS continues using the original opaque 1024px artwork from
`pi-studio/Assets.xcassets/AppIcon.appiconset`. The legacy macOS PNG slots remain
in that catalog but are not the selected macOS app icon.
Validate the legacy icon slots, PNG sizes and opaque iOS format with
`python3 scripts/test-app-icons.py`.

## Architecture

- [PiUI](Packages/PiUI/Package.swift) is a local Swift package shared by both
  platforms. It depends on public [PiSDK](https://github.com/ManuelSelch/pi-sdk-swift)
  **0.1.0** and [Flux](https://github.com/ManuelSelch/Flux) **2.0.1**
  (including FluxTestStore and the corrected iOS 16 minimum), both pinned exactly,
  and [FactoryKit](https://github.com/hmlongco/Factory) from **2.5.3**, allowing compatible 2.x updates.
- [Dependency registrations](Packages/PiUI/Sources/PiUI/Session/App/SessionDependencies.swift)
  extend FactoryKit's Container. The app uses Container.shared; tests/previews own
  independent containers. Registrations include session configuration, the SDK
  connection builder and cached main-actor session/settings stores.
  Each store owns a fresh middleware instance. The shell and session container resolve
  the same store; previews/tests use separate scopes. Install overrides before resolution. Native UI
  tests register their debug connection through the same dependency graph.
- [SessionFeature](Packages/PiUI/Sources/PiUI/Session/App/SessionFeature.swift) holds app-owned
  interaction state and typed reducer actions. FluxStore is the sole observable
  source of session interaction state. Editable message text stays local to the
  composer; only submitted snapshots and consumable matching-clear instructions
  cross the store boundary. Typing dispatches no session actions.
- [SessionMiddleware](Packages/PiUI/Sources/PiUI/Session/Middleware/SessionMiddleware.swift)
  owns SDK effects, observation tasks and disposal. Containers only dispatch
  `connectRequested`, `sendRequested(text:)`, `stopRequested`, `disconnectRequested`
  and `clearDraftConsumed`. The reducer validates readiness/content and synchronously
  reserves accepted requests; middleware submits the exact action snapshot. Request IDs
  prevent duplicate SDK calls and generation tokens reject obsolete results.
  Middleware-owned tasks capture only the weak-backed store handle across SDK
  suspension, so releasing the store cancels work and disconnects the client.
  Disconnect cancels and joins pending work/streams before `disconnectFinished`;
  Connect stays disabled until disposal settles.
  These lifecycle tasks are owned by middleware, not tracked by Flux `finish()`.
  Tests await result actions/state and explicitly disconnect before draining.
  This does not stop or close the server runtime.
- [Containers](Packages/PiUI/Sources/PiUI/Session/SessionContainer.swift) bridge Flux, injected
  dependencies and callbacks to presentation. ObservableObject stores use
  `@InjectedObject`, not `@Injected`, so SwiftUI observes state publications. Future navigation/router wiring
  belongs here or in the host shell. The selected routing library is
  [Router](https://github.com/ManuelSelch/Router), but integration is deferred by
  agreement: version 1.0.10 unconditionally depends on UIKit-only SwiftEntryKit
  and UIHostingController and cannot build natively for macOS. No substitute
  router is introduced; settings uses native sheet presentation.
- [Components](Packages/PiUI/Sources/PiUI/Session/UI) take plain display values and
  callbacks, using SwiftUI and narrowly scoped native editing/event adapters.
  They do not read stores, resolve services, use SDK models or perform network
  work. Local draft/focus/alert state is UI-only.
- The [app shell](pi-studio/pi_studioApp.swift) owns lifetime and native windows.
  iOS backgrounding disposes local networking. macOS losing focus does not;
  closing its single window disposes the local connection.
- PiSDK owns protocol validation, request correlation, transport, authoritative
  session projections and run settlement. It does not depend on Flux or PiUI.

## Development wiring

- Verified stable toolchain: **Xcode 26.1.1 (17B100), Swift 6.2.1**.
- SwiftPM fetches public PiSDK **0.1.0**, Flux **2.0.1**, and FactoryKit automatically.
  PiUI and the native Xcode project use the same exact SDK/Flux requirements.
- Run `bash scripts/prepare.sh` in a fresh checkout or worktree to resolve the
  PiUI package dependencies. Xcode resolves its dependencies when opening/building
  the project. No local SDK/Flux checkouts or dependency symlinks are required.
- Keep both Package.resolved files checked in. Existing ignored local dependency
  folders are unused and are not deleted by preparation.

[SessionConfiguration](Packages/PiUI/Sources/PiUI/Session/App/SessionConfiguration.swift)
defaults to `ws://127.0.0.1:8787/ws` and the dedicated **server-side** directory
`/tmp/pi-studio-demo`. Create that directory and start the local v2 Pi Server
before connecting. The app does not start/install the backend or store model
credentials. The endpoint can be changed from **Settings** in the session header;
the server-side working directory remains development configuration.

### Endpoint settings

- The native sheet has one endpoint field, inline errors, Cancel and Save, without
  helper text. Edits are drafts until Save; Cancel or dismissal discards them.
- Accepts full `ws://` or `wss://` URLs with a host, preserving port/path/query
  and trimming surrounding whitespace. Credentials, fragments and invalid URLs
  are rejected. Nothing probes the server or appends a path.
- Saved endpoints persist per installation in UserDefaults (`pi.serverEndpoint`).
  Missing/invalid stored values fall back to `ws://127.0.0.1:8787/ws`.
- Save changes the **next explicit Connect** only. Active/in-flight connections
  keep their endpoint snapshot and are not disconnected or restarted. The header
  distinguishes current and next endpoints when they differ.
- [Settings](Packages/PiUI/Sources/PiUI/Settings) is a vertical Flux feature.
  SettingsMiddleware uses `@Injected` for the small `EndpointSettingsService`
  protocol. Its factory binds FactoryKit's task-local container during construction
  so independent scopes stay isolated. Only `UserDefaultsEndpointSettingsService` touches UserDefaults.
  Tests inject in-memory services or isolated suites, never personal defaults.
  The settings store loads a validated saved/default endpoint at construction.
  Save is reserved by the reducer before middleware runs; request IDs reject
  duplicate work. FactoryKit caches both stores and the service within the container.
- Explicit configuration overrides still win; the app resolves the endpoint
  when Connect middleware begins, before any SDK suspension, not when the store is created.
  UserDefaults provides no durable-write acknowledgement. This adds no remote
  authentication, automatic reconnect or transport-security exceptions.

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
- The editor wraps and grows from two to five lines, then scrolls internally.
  macOS Enter sends and Shift+Enter inserts a newline at the caret. iOS Return
  inserts a newline; only the ↑ button submits. No routine composer hints are shown.
- Send permits one non-whitespace plain-text prompt while idle and preserves exact
  indentation, blank lines and surrounding whitespace. Slash/bash commands,
  steering and queued messages are deliberately unsupported. Drafts clear only
  after admission, remain on rejection/unknown outcome, and are never replayed.
- SDK-owned complete projections deliver incremental text, ordered messages and
  finalized answers without duplicate drafts. Admission is not answer completion.
- macOS Esc (no separate Stop button) and the iOS running-state stop icon invoke
  the same guarded cancellation effect. Stop retains partial text and shows
  Stopping until authoritative settlement.
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
**Current user instruction: do not run macOS automation tests until authorized.**
The macOS composer interaction scenarios are compiled, not executed.

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

Do not run two worktrees' native UI suites against the same Simulator at once.
They share the app bundle identifier, so one installation can replace the other
while its runner supplies framework paths from a different build. This can cause
DYLD missing-symbol crashes and misleading macOS compatibility dialogs. Use
separate Simulator devices via `PI_STUDIO_TEST_DESTINATION` (or run serially);
separate derived-data directories alone do not isolate Simulator installations.

- PiUI: **42 named tests** (including parameterized URL cases), covering settings
  reducers, mock-service failure/retry, isolated UserDefaults persistence,
  next-connection snapshots during setup/streaming, and dependency scope
  identity/isolation, configuration/connection overrides, FluxTestStore reducer
  transitions, draft admission/retention, duplicate guards, stale callbacks,
  setup/pending-send disconnect, connection errors and deallocation disposal.
- The settings connection integration scenario and semantic driver also compile
  into both native unit-test targets; their source is shared, not copied.
- iOS: 15 functional UI tests (including six multiline scenarios), plus four
  launch/appearance cases. macOS has corresponding Return/Shift+Return,
  paste/selection/undo, duplicate admission, Escape and retention scenarios,
  compiled but not executed during the automation pause. Debug-only injected
  connections are never selected by normal app launches; tests use public SDK
  projections, not a second wire protocol.
- For current verification and outstanding native macOS/IME/physical-keyboard
  checks, see [implementation status](docs/multiline-composer/IMPLEMENTATION.md).
  No macOS interaction verification is claimed while automation is paused.

### Semantic test DSL

Integration and functional UI scenarios use lowerCamelCase feature drivers:
`app.session.connect()`, `app.chat.sendPrompt(...)`, `app.settings.open()` and
semantic assertions.
Drivers hide stores, middleware, SDK projections, selectors and synchronization;
`app.server` separately controls integration fixtures. Both roots own cleanup.

See [testing drivers](docs/testing-drivers.md) for architecture, examples and
extension rules. Reducer tests remain focused FluxTestStore unit tests.

### Explicit isolated transport acceptance

Normal suites skip the opt-in network test. To exercise **PiUI + Flux + actual
URLSession/Pi Server transport** without model credentials:

```sh
bash scripts/test-simulator-loopback.sh ios
bash scripts/test-simulator-loopback.sh macos
```

This requires pi-chat's installed Node/tsx dependencies and packed SDK dependency
(`npm ci` and `npm run verify:sdk` there). The fixture lives under `test/swift-integration/fixtures` in Pi Chat, not inside the SDK. Override `PI_CHAT_CHECKOUT` if needed.
The script owns an ephemeral-loopback fake-runtime server with temporary metadata
and empty history. It verifies streaming, a second turn, Stop/retained text and
disconnect through SessionMiddleware, then verifies exactly one retained runtime
is explicitly closed and the test-owned server is stopped. It never points to the
user's development server. Failure logs are retained in a temporary directory.

## Limitations

Controlled **real-model Pi acceptance is still outstanding**; fake-runtime tests
are not model-provider proof. Dialog answers, Markdown, tool/thinking rendering,
session browsing/opening, public close APIs, reconnect/gap recovery, optional
extension UI and secure remote access remain out of scope. Sequence gaps fail
explicitly instead of attempting recovery. This remains a subset of the parent
SDK Swift vertical slice, not full parity or a complete Pi Chat replacement.
