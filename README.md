# Pi Studio / Pi Pocket

Native SwiftUI for **macOS 26** (Pi Studio) and **iOS 26.1** (Pi Pocket), sharing
PiUI and PiSDK. The `pi-studio` target/scheme builds natively on both platforms;
select **My Mac** for desktop, not Catalyst.

Pocket slice 1 adds a compact project/session browser. Connect lists the server's
projects without creating a demo session. Quick Chats stays first; expand a
project, open saved history or a running session, or use **+** to explicitly start
a session. Conversation supports plain-text streaming, idle Send and Stop.
There is no Pi Pocket title, server label, endpoint editor or explanatory footer.
The approved reference is [mockup revision 2](mockups/pocket/DESIGN.md).

The root [requirements](REQUIREMENTS.md) preserve the original demo MVP;
[Pocket requirements](docs/pi-pocket/REQUIREMENTS.md) define the follow-on slices.
This is still a localhost development client, **not a remotely deployed phone
controller**. Foreground recovery, steering and question responses are later slices.

## Development wiring

- Baseline: **Xcode 26.1.1 (17B100), Swift 6.2.1**, macOS 26 and iOS 26.1 targets.
- Required Swift SDK: pi-chat commit **`3abb883`**, branch **`feat/pocket-sdk`**,
  or a later revision containing its APIs. SDK changes are isolated from pi-chat
  main and have not been pushed, published or merged there.
- This worktree's ignored `.dependencies/pi-sdk` symlink points to
  `~/.worktrees/pi-chat/feat-pocket-sdk/packages/pi-sdk`.
- For a fresh worktree, prepare with that SDK explicitly:

```sh
PI_SDK_PATH="$HOME/.worktrees/pi-chat/feat-pocket-sdk/packages/pi-sdk" bash scripts/prepare.sh
```

Preparation creates the symlink and resolves the pinned packages. The normal
fallback SDK location is `~/.pi/agent/git/pi-chat/packages/pi-sdk`; it must contain
the required browsing API before it can replace the override above. Local SDK
sources are not fetched, updated or published automatically. Keep both
Package.resolved files tracked.

The fixed development endpoint remains **`ws://127.0.0.1:8787/ws`** in
[SessionConfiguration](Packages/PiUI/Sources/PiUI/App/SessionController.swift).
Start the local v2 Pi Server before connecting. No endpoint settings were added;
the user will provide a separate settings feature later. On a physical phone,
loopback refers to the phone, not the development Mac.

The old demo-only API still uses the isolated server directory
`/tmp/pi-studio-demo`; product browsing does not use it. New sessions use the
chosen project's server-side folder; Quick Chats uses the server-designated home
folder, not the phone's filesystem. The app starts no server and stores no model
credentials. Keep the backend loopback-only. Debug permits narrow local networking
through [DebugInfo.plist](Configuration/DebugInfo.plist); Release has no global
ATS exemption. The Mac sandbox permits outgoing connections.

## Behavior and safety

- Nothing connects automatically. Explicit consent precedes single-controller
  handoff; concurrent desktop/phone control is intentionally unsupported.
- Initialization uses the server's cached catalogue. Cold catalogue updates
  arrive asynchronously and update the list without another connection.
- Saved history paths and fresh runtime IDs are distinct. Attach an inventoried
  runtime using a fresh snapshot; opening saved history reuses a known runtime
  when available. Failed opens do not create fallback sessions. Opening/creation
  guards prevent duplicate submissions.
- Repository checkouts/worktrees group together; branch context remains on the
  session row. Archived history is hidden. Running/blocked/closing sessions are
  distinguished; missing project folders disable new-session creation.
- Projects back changes local navigation only. Server work is neither stopped nor
  closed. Drafts are isolated by runtime within the current connection.
- Plain-text Send is enabled only while idle. No slash/bash commands, steering or
  question responses are implemented yet. Drafts clear only after admission;
  rejection and unknown outcomes retain them. Mutations are never replayed.
- Stop retains partial text and waits for authoritative settlement. Admission is
  not completion. Deadlines, malformed required data and sequence gaps fail
  explicitly. Unsupported structured questions are reported rather than treated
  as completed answers; blocked background sessions can still be listed.
- Disconnect warns about active/pending work and never implicitly aborts/closes
  server runtimes. An open conversation's observed transcript remains visible.
  New Connect returns to browsing, not a new demo. Uncertain opens require an
  explicit disconnect/reconnect before retrying; inspect server state first.
- iOS backgrounding disposes networking. macOS losing focus does not; closing its
  single window disconnects. Automatic reattachment/recovery is slice 2.

## Architecture

- Local [PiUI](Packages/PiUI/Package.swift) depends on PiSDK, Flux pinned to
  `00c8b43799d5acbca04127833daf28f1df2ce477`, and FactoryKit **2.5.3**.
- [SessionDependencies](Packages/PiUI/Sources/PiUI/App/SessionDependencies.swift)
  is an app-owned FactoryKit scope, not a singleton. It caches the shared
  SessionController and ProjectsController. Tests/previews own separate scopes
  and install overrides before resolution.
- [Projects](Packages/PiUI/Sources/PiUI/Projects) owns browsing/navigation in a
  Flux feature, SDK-facing controller, plain domain values and pure components.
  The thin ProjectsContainer binds state and callbacks to presentation.
- The existing SessionController/SessionFeature own conversation interaction
  state. Explicit session adoption reuses the browsing connection without
  creating or closing runtimes. The legacy demo entry point remains available
  for focused regression/transport tests, but is not the product Connect flow.
- Components import SwiftUI only and accept values/callbacks; they never resolve
  services, parse protocol data or read stores. Focus, disclosure and confirmation
  flags remain UI-only. SDK effects feed typed Flux actions; generation tokens
  reject obsolete callbacks. Long-lived observation is explicitly cancelled.
- PiSDK owns transport, contract validation, request correlation, catalogue
  revisions and authoritative session projections independently of Flux/SwiftUI.
- The selected Router library remains deferred until it supports native macOS.
  No substitute router was introduced for this small navigation flow.

## Verification

[.pi/pipeline.json](.pi/pipeline.json) provides seven serial suites. Only `piui`
runs automatically; native UI automation is manual because it controls the
Simulator/desktop. After preparing the SDK dependency:

```sh
bash scripts/test-package.sh
bash scripts/test-app.sh ios unit
bash scripts/test-app.sh ios ui
bash scripts/test-app.sh macos unit
bash scripts/test-app.sh macos ui
bash scripts/test-app.sh ios release
bash scripts/test-app.sh macos release
python3 scripts/test-simulator-isolation.py
```

All seven suites passed together for Pocket slice 1: **24 named PiUI tests**,
**9 native unit tests plus the normally skipped transport acceptance** on each
platform, **8 functional UI tests** plus launch/appearance tests (12 total on
iOS, 10 on macOS), and both Release builds. SDK Swift tests: **28 passed**,
including a real isolated Pi Server/fake-runtime loopback that proves browsing,
Quick Chats publication, explicit creation, streaming, fresh-client attachment,
Stop, disconnect retention and explicit cleanup. Four test-script isolation
checks also pass. No live user sessions or model credentials were used.

Tests use lowerCamelCase semantic drivers, with fixture controls separate from
app actions. See [testing drivers](docs/testing-drivers.md). Screenshots of the
native projects and saved-chat views are attached to the browsing UI tests;
exported local artifacts live under ignored `.build/ui-artifacts`.

### Worktree isolation and macOS launch diagnostics

Products and test working directories live outside Documents/Desktop/Downloads
under `~/Library/Developer/Xcode/DerivedData/PiStudio-<worktree-hash>`; override
`PI_STUDIO_BUILD_ROOT` only with another non-protected location. Do not grant
Full Disk Access as a workaround for test-product placement. macOS uses ad-hoc
signing so local UI runners can launch; iOS Simulator builds disable signing.

Each worktree now reuses/creates its own **PiStudio-<worktree-hash>** iPhone 17
Simulator. Override `PI_STUDIO_TEST_DESTINATION` to select another device, but
avoid sharing it with concurrently tested worktrees: identical app/test bundle
IDs can replace each other's installed binaries despite separate DerivedData.
A concurrent settings/Pocket run caused a launch-time DYLD missing-symbol error
and a generic macOS compatibility alert. Dedicated Simulator reruns passed;
no OS update or app reinstall was needed. This diagnosis applies to that test
collision, not to every future launch error.

### Explicit isolated transport acceptance

```sh
bash scripts/test-simulator-loopback.sh ios
bash scripts/test-simulator-loopback.sh macos
```

These opt-in tests exercise SessionController/Flux and real URLSession transport
against a script-owned ephemeral fake-runtime server. Install pi-chat Node/tsx
dependencies and build its SDK dist first; override `PI_CHAT_CHECKOUT` if needed.
The script checks exactly one retained runtime is explicitly closed, stops its
own server and retains temporary failure logs. It never points at a live backend.

## App icons

Both platforms use Pi Chat's black π on white. iOS uses the opaque 1024px source
and the system mask; macOS uses a rounded inset tile on a transparent canvas.
Assets are in [AppIcon.appiconset](pi-studio/Assets.xcassets/AppIcon.appiconset).
Validate slots, sizes and opacity with `python3 scripts/test-app-icons.py`.

## Remaining limits

Controlled **real-model acceptance remains outstanding**; fake-runtime proof is
not provider acceptance or full Swift SDK parity. There is no foreground/relaunch
recovery, steering, structured question interaction, public runtime-close UI,
remote authentication/TLS deployment, Markdown, rich tool/thinking UI or
attachments. Navigating across independent server installations does not sync
histories or runtimes. Clean retained test/demo runtimes through Pi Chat or an
explicit server `session.close`; disconnecting alone never removes them.
