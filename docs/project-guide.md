# Pi Studio / Pi Pocket — shared native session demo

Native SwiftUI for **macOS 26** (Pi Studio) and **iPhone/iPad iOS 26.1**
(Pi Pocket). The existing `pi-studio` scheme/target builds for both platforms;
select **My Mac** for a native desktop app, not Catalyst. The mobile product is
still a Simulator/local-server demo, not a remotely deployed phone controller.

The app opens to a Home screen with a centered quick-switcher field; clicking it
focuses the field, and typing expands search inline. On macOS, ⌘K / ⌘O also opens
it. The search draft survives dismissal and reopening. On a conversation, macOS ⌘K / ⌘O opens the switcher overlay;
iOS also provides a search button. Filters use # for folders, % for worktrees,
@ for sessions and / for actions (currently empty). Selecting a folder or worktree
creates a session there; selecting a session opens or focuses it. Folder and worktree
rows omit paths; worktrees show their repository and branch. Tab and Shift+Tab cycle
filters in opposite directions. Escape or a click/tap outside dismisses the switcher.
Folders and worktrees reported missing by the server are hidden, while their saved sessions remain searchable. Archived history is excluded. The session inbox remains available for navigation. Launch automatically
connects to the configured server and takes control without creating or attaching
to a session. A failed connection is shown on Home with a retry action. Conversations
use a Markdown transcript, multiline message field, icon-only ↑ Send and errors.
macOS Esc stops an active run; iOS replaces Send with a stop icon while running.
The approved layouts are preserved in
[mockups/session](../mockups/session/DESIGN.md), [mockups/settings](../mockups/settings/DESIGN.md)
and [mockups/multiline-composer](../mockups/multiline-composer/DESIGN.md).

## Documentation layout

- [Current-system documentation](README.md): maintained guides for the system as implemented.
- [Plans](../plans/README.md): requirements, backlog, designs, research and implementation/verification records; not current-system authority.
- [Mockups](../mockups/): preserved UI prototypes and their approval records.

Keep temporary requirements and design files in `../plans/`, not `docs/` or the repository root.

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

See the dedicated [architecture document](architecture.md) for component ownership, feature state and effects, dependency boundaries, and runtime flow.

## Development wiring

- Verified stable toolchain: **Xcode 26.1.1 (17B100), Swift 6.2.1**.
- Every dependency is a pinned public release resolved through SwiftPM: PiSDK
  **0.2.0** (`ManuelSelch/pi-sdk-swift`), Flux **2.0.1**, Router **2.0.0**,
  FactoryKit **2.5.3**, swift-markdown **0.7.3**, and SwiftStreamingMarkdown
  **0.7.0** pinned to its release commit because its manifest uses
  revision-based dependencies. No local SDK checkout or path override is needed.
- Run `bash scripts/prepare.sh` before opening Xcode or testing on a fresh
  checkout/worktree. The script resolves the pinned remote dependencies.
- Xcode's Package.resolved files pin the same remote dependencies, so a fresh
  checkout and hosted CI resolve identical revisions.
- AppContainer owns the settings modal scope through Router; inbox/session
  selection and phone navigation remain workspace state. Both platform shells
  use the session inbox sidebar; iPhone opens it from Home and retains its open-sessions overview.

[SessionConfiguration](../Packages/PiUI/Sources/PiUI/Session/App/SessionConfiguration.swift)
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
  Missing/invalid stored values fall back to `ws://127.0.0.1:8787/ws`. The launch
  connection uses the saved endpoint loaded by the settings store.
- Save changes the next connection only. Active/in-flight connections keep their
  endpoint snapshot and are not disconnected or restarted.
- [Settings](../Packages/PiUI/Sources/PiUI/Settings) is a vertical Flux feature.
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
[DebugInfo.plist](../Configuration/DebugInfo.plist); Release has no ATS exception.
The macOS app sandbox permits outgoing network connections. No global arbitrary
loads exemption, remote-device networking, proxy or auth was added. On a physical
iPhone, loopback refers to the phone, not your Mac.

## Behavior

- Launch automatically takes control: initialization replaces the existing server
  controller. **Single-controller handoff is intentional**; simultaneous Studio
  and Pocket control is not required. Retry after a failed connection also takes
  control directly. Neither launch connection nor retry creates or selects a session.
- The server catalogue drives the inbox: blocked sessions appear under Needs you,
  unarchived idle saved sessions under Ready, and working sessions under Running.
  Later is a local, endpoint-scoped UserDefaults state for idle saved sessions;
  parking closes a loaded runtime with `closeSession`, and resuming reopens its
  saved history path. Archiving remains independent. Launch/retry do not attach to
  existing runtimes or abort/close them.
- The editor wraps and grows from two to five lines, then scrolls internally.
  macOS Enter sends and Shift+Enter inserts a newline at the caret. iOS Return
  inserts a newline; only the ↑ button submits. No routine composer hints are shown.
- The composer remains editable while a session is running so the user can prepare
  the next prompt; Send is available only while idle. Send permits one non-whitespace
  plain-text prompt and preserves exact indentation, blank lines and surrounding
  whitespace. Slash/bash commands, steering and queued messages are deliberately
  unsupported. Drafts clear only after admission when they still match the submitted
  text, remain on rejection/unknown outcome, and are never replayed.
- SDK-owned complete projections deliver incremental text, ordered messages and
  finalized answers without duplicate drafts. The transcript renders user prompts
  and assistant replies as Markdown as snapshots arrive; sending preserves the raw
  prompt. Leading spaces in ordinary top-level prompt paragraphs and trailing
  newlines after them remain visible; Markdown block indentation retains its syntax.
  Admission is not answer completion.
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

## GitHub Actions

[CI](../.github/workflows/ci.yml) runs on pull requests, pushes to `main`, and
manual dispatch. The hosted `macos-26` build selects Xcode 26.2 and runs one job:

- **Package:** PiUI tests, released-dependency/lockfile checks, icon validation,
  Simulator-isolation tests and loopback-launcher tests (no actual backend). The
  PiUI tests are the unit, integration-driver and screen-driver scenarios; they
  run headlessly, without a Simulator.

Native app tests are **manual-only**, because building the app for a Simulator is
what makes them slow:

- [iOS native tests](../.github/workflows/ios-native.yml) runs the iOS native unit
  suite (the integration drivers linked into the iOS app) and then the native UI
  suite. Each suite builds only its own test bundle once and then runs it without
  rebuilding (`build-for-testing` + `test-without-building`); it reuses the
  preinstalled iPhone 17 and starts it booting in the background so boot overlaps
  the build.
- [macOS UI tests](../.github/workflows/macos-ui.yml) runs the macOS native UI
  suite without controlling your Mac. Hosted UI-testing authorization is not yet
  verified; an Accessibility failure remains a failed test run, not a skip.

Run them from **Actions → the workflow → Run workflow**, or with
`gh workflow run ios-native.yml` / `gh workflow run macos-ui.yml`.

[Release builds](../.github/workflows/release.yml) is a separate workflow for the
native Release (**shippability**) compile checks. It runs only on tag pushes and
manual dispatch, never on regular pushes or PRs, and builds the iOS Simulator and
macOS apps in parallel. These verification builds target only the host
architecture (`ARCHS=$(uname -m)`) rather than the unused universal slice. Because
app compilation is tag-gated, `#if DEBUG`-only and whole-module optimization
regressions surface at release time, not on every PR.

The Xcode build jobs explicitly use `-skipMacroValidation` for the Equatable
macro dependency. This skips validation for every compiler macro in those builds;
local Xcode builds can instead use **Trust & Enable** for the specific macro.
SwiftPM fetches every dependency from its public repository (PiSDK 0.2.0, Flux
2.0.1, Router 2.0.0, FactoryKit, swift-markdown 0.7.3, SwiftStreamingMarkdown
0.7.0), so hosted CI resolves the same revisions as a fresh local checkout.
No model credentials or development server are needed for the listed checks.
Each job has isolated temporary build products, bounded execution and failure logs
retained for seven days; iOS failures also upload available `.xcresult` bundles.
Superseded runs are cancelled. There is no caching, deployment, distribution
signing, real-model acceptance or branch-protection configuration.
A push or PR is needed to verify the workflow on hosted runners.

## Test pipeline

[.pi/pipeline.yaml](../.pi/pipeline.yaml) configures once-per-worktree preparation and
six independent suites. Only fast `piui` tests opt into after-agent execution;
iOS UI automation is manual because it uses the Simulator. `macos-ui` is excluded
from the local pipeline and runs only through the manual GitHub workflow above.
**Do not run desktop-controlling macOS automation on the development Mac.**
The retained local `macos-unit` suite also remains paused until authorized.
PiUI package tests drive hosted editors off-screen without activating windows or
posting system input.

Equivalent commands after preparation:

```sh
bash scripts/prepare.sh
bash scripts/test-package.sh
bash scripts/test-app.sh ios unit
bash scripts/test-app.sh ios ui
bash scripts/test-app.sh macos unit # paused locally; requires authorization
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

- PiUI tests cover settings
  reducers, mock-service failure/retry, isolated UserDefaults persistence,
  next-connection snapshots during setup/streaming, and dependency scope
  identity/isolation, configuration/connection overrides, FluxTestStore reducer
  transitions, draft admission/retention, duplicate guards, stale callbacks,
  setup/pending-send disconnect, connection errors and deallocation disposal;
  workspace session selection and reading-position isolation; and off-screen Mac composer width/hit testing,
  typing, selection newline, undo/redo, submit guards and Escape focus transitions.
- The settings connection integration scenario and semantic driver also compile
  into both native unit-test targets; their source is shared, not copied.
- Native UI coverage is limited to a Mac conversation journey, an iOS conversation
  journey, and settings persistence on each platform. Error and workflow variants
  are exercised in PiUI. Native text selection, long-input scrolling, detailed
  toolbar layout, appearance permutations, and platform-specific dismissal are
  not covered by these smoke journeys. Debug-only injected connections are never
  selected by normal app launches; tests use public SDK projections, not a second
  wire protocol.
- For current verification and outstanding native macOS/IME/physical-keyboard
  checks, see [implementation status](../plans/multiline-composer/IMPLEMENTATION.md).
  Off-screen checks are not full desktop, real-IME or physical-keyboard acceptance.

### Semantic test DSL

Integration and functional UI scenarios use lowerCamelCase feature drivers:
`app.session.connect()`, `app.chat.sendPrompt(...)`, `app.settings.open()` and
semantic assertions.
Drivers hide stores, middleware, SDK projections, selectors and synchronization;
`app.server` separately controls integration fixtures. Both roots own cleanup.

See [testing drivers](testing-drivers.md) for architecture, examples and
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
are not model-provider proof. Dialog answers, tool/thinking rendering,
archive browsing and unarchiving, reconnect/gap recovery, optional extension UI and secure remote
access remain out of scope. Sequence gaps fail
explicitly instead of attempting recovery. This remains a subset of the parent
SDK Swift vertical slice, not full parity or a complete Pi Chat replacement.
