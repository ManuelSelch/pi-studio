# Pi Studio MVP and Endpoint Settings — Requirements

## Goal
Prove that a native SwiftUI application can use PiSDK to connect to Pi Server, create one isolated session, exchange streaming text messages, stop a response and disconnect cleanly. This is the first small SDK-backed vertical slice toward a native desktop replacement for Pi Chat, not a full chat application or a claim of complete Swift SDK support. The next small vertical slice adds Flux-backed endpoint settings with mockable local persistence.

## Scope
### In Scope
- One native SwiftUI window with connection status, Connect/Disconnect, a plain-text transcript, a message field, Send, Stop and a visible error area.
- A configurable Pi Server WebSocket endpoint, initially defaulting to the development endpoint; the dedicated server-side demo working directory remains development-configured.
- One shared native settings feature for macOS and iOS: draft editing, explicit Save, validation, local persistence and connection integration.
- One dedicated session per successful explicit connection, created only after v2 initialization and controller admission succeed.
- The minimal reusable Swift SDK implementation required for this flow, developed in the existing Pi SDK package rather than inside the app.
- Deterministic SDK/app tests and a controlled real-Pi smoke test.
- Native macOS Pi Studio and the existing iOS app (future Pi Pocket), sharing a local PiUI Swift package.
- Flux state management, container/component separation, and reproducible local test pipeline suites.

### Out of Scope
- Replacing Pi Chat in full, a complete mobile agent-steering product, distribution or App Store submission.
- Session browsing, opening saved history, multiple sessions/windows, project navigation and persistent app state beyond the saved server endpoint.
- Markdown, attachments, tool-detail rendering, thinking display and optional extension UI.
- Structured question interaction, model/provider selection, steering and queued messages.
- Automatic reconnect, recovery across launches, remote devices, proxy setup, authentication and OAuth.
- Server repository extraction, SDK publication, remote repository creation or pushing commits.

## Requirements
- R1. Keep PiSDK independent of SwiftUI and the application. The app consumes the SwiftPM product `PiSDK`; wire models, transport, request correlation, protocol validation and session projection live in the SDK. App state owns the input draft and presentation only. Do not copy the TypeScript protocol into an independently maintained app implementation.
- R2. Implement against the authoritative v2 contract and shared fixtures in the Pi SDK workspace. The existing Swift package is a scaffold/schema probe, not an already functional client. This MVP is a subset of backend/SDK plan slice 7; it does not complete that slice's dialog and reconnect requirements.
- R3. On Connect, initialize the connection, obtain controller access according to the server contract and create exactly one demo session in a configured isolated server-side directory. Show ready only after the session is usable. Never silently take over another controller, attach to live user sessions or start a second create operation because a button was clicked twice.
- R4. Display disconnected, connecting, ready, generating and failure states clearly. Disable actions that are invalid in the current state. Distinguish a successful socket connection from successful protocol initialization and session readiness.
- R5. Send a nonempty plain-text prompt only while the demo session is idle. Clear the submitted draft after confirmed admission, retain it on a definite rejection, and visibly distinguish an uncertain outcome. Never automatically replay a mutation. An admission receipt is not answer completion.
- R6. Display user messages and incremental assistant text from SDK session projections, preserving ordering and avoiding duplicate text. Mark completion from the authoritative run lifecycle rather than socket closure or receipt of the first response. Allow a second turn in the same session after completion.
- R7. Stop requests cancellation of the active run through PiSDK. Keep the partial answer visible and wait for authoritative settlement before reporting the session idle; cancellation admission alone is not completion.
- R8. Display connection, protocol and domain errors without indefinite spinners. Pending requests have bounded deadlines. Unknown outcomes are not presented as definite failures or retried automatically. Unsupported required protocol data fails explicitly; optional presentation data may be ignored. If a structured question occurs, identify it as unsupported in this MVP rather than presenting it as an ordinary completed answer.
- R9. Disconnect and app teardown stop local receiving/tasks, settle outstanding local requests and ignore obsolete callbacks. They do not implicitly abort or close the server runtime. Warn before disconnecting an active run that server work may continue. An unexpected disconnect ends this demo connection; recovery/resuming its session is out of scope. A later explicit Connect creates a fresh demo session and resets the displayed transcript, without implying that the old server runtime was closed.
- R10. Keep demo runtime creation bounded to explicit user connections, document retained-runtime cleanup and clean up smoke-test runtimes through explicit close operations. Use an isolated temporary server/runtime fixture for automated tests. No tests may manipulate live user sessions or depend on private conversation data.
- R11. Use concurrency-safe SDK ownership and UI updates on the main actor. Bound incoming buffering and outstanding requests; malformed required data, overload and transport closure must settle or fail explicitly. Local disposal must be deterministic even during connection setup or streaming.
- R12. Use a development-only loopback/private server without exposing it to the network. Any necessary local networking permissions or transport-security exceptions must be narrowly scoped; do not disable transport security globally. The server supplies existing model credentials/defaults; the app stores none.
- R13. Link the SDK as an explicit local SwiftPM dependency during development and document its checkout location and required revision. SDK changes belong in the SDK workspace, starting from the current main containing slices 1–6, not the older backend cutover checkout. No publication or repository split is necessary for this MVP.
- R14. Before implementation, record the installed stable Xcode/Swift versions and chosen deployment target, reconciling them with the parent SDK plan's stable-toolchain policy. Verify the reusable package with SwiftPM and the app on the agreed native target. Do not silently convert or remove the existing iOS targets.
- R15. Acceptance: connect to a controlled local Pi Server; send “Say hello”; observe incremental text and normal completion; send a second prompt; stop the active response; observe settled state with partial text retained; disconnect without hangs. Also verify unreachable server, rejected initialization/controller access, rejected send and disconnect during a pending request. Record what was tested and which SDK operations remain unsupported.
- R16. PiUI owns shared app state through Flux features/reducers, never a second wire protocol. SDK lifecycle effects feed typed actions into the store. PiSDK stays independent of Flux and SwiftUI.
- R17. Containers bridge Flux, app dependencies and navigation to presentation. UI components accept values and callbacks only; they must not import Flux, resolve dependencies or perform SDK operations. Preserve the approved single-screen layout; no router is necessary yet.
- R18. The existing app target must build natively for both macOS and iOS; do not use Catalyst or remove iOS coverage. Platform shells own windows and lifecycle. macOS deactivation must not disconnect a session; iOS backgrounding still disposes local networking. Single-controller handoff is accepted.
- R19. A local PiUI package and pinned Flux dependency must resolve from a fresh worktree. Configure approved package, native unit/UI and Release-build pipeline suites. Automated tests use stubs or isolated fixtures, never the live backend or real model credentials.

- R20. Provide a discoverable Settings entry from the session screen on both platforms. Opening settings shows the saved endpoint, or the development default on first use. Edit a draft; only explicit Save changes the saved value. Cancel/dismiss discards unsaved edits. Show validation and save feedback without starting a connection.
- R21. Accept an absolute URL with a `ws` or `wss` scheme and a nonempty host. Trim surrounding whitespace; preserve explicit port/path/query. Reject empty or malformed URLs, unsupported schemes, embedded credentials and fragments. Show an inline validation error without saving. Do not silently append `/ws` or test reachability. Endpoint configuration does not add remote authentication support or broaden transport-security exceptions.
- R22. SettingsFeature owns draft, saved value, validation and save status through Flux state/actions/reducer. A small effect/controller layer invokes persistence and dispatches results, without a second observable settings model. SettingsContainer bridges store/dependencies and presentation; components import SwiftUI only and accept plain values/callbacks.
- R23. Put loading/saving behind a small injectable endpoint-settings service protocol; only its production adapter accesses UserDefaults. Register it in the existing app-owned FactoryKit scope and inject it into the effect owner. Reducers, views and SessionMiddleware must not access UserDefaults directly. No Keychain, generic preferences framework or PiSDK changes are needed for this non-secret setting.
- R24. Persist only validated endpoints. Missing/invalid stored data falls back to `ws://127.0.0.1:8787/ws` without crashing or connecting automatically. On a service-level save error, show the error, retain the draft for retry and leave the effective endpoint unchanged. UserDefaults does not acknowledge durable disk writes; do not claim that guarantee or use `synchronize()`.
- R25. Confirmed policy: load the effective endpoint at launch and snapshot the latest saved endpoint on each explicit Connect, rather than freezing it when the cached session store is created. Save affects the next Connect only; active/in-flight connections keep their snapshot. Save never reconnects, disconnects, takes control or replays work. Keep the server-side working directory unchanged. Show the actual current-connection endpoint, distinguishing a saved next-connection endpoint when different.
- R26. Cover default/loading, valid save/reload, invalid input, cancel, save failure/retry and dependency isolation with FluxTestStore and effect-owner tests using a mock/in-memory service. Test the production adapter with unique UserDefaults suites cleaned up after each test. Extend semantic integration/UI drivers with `app.settings`; verify changing settings after session-store resolution, next-connection URL selection, and saving during active/in-flight connections. On macOS and iOS, verify settings editing and persistence across relaunch using isolated defaults and stub connections, never personal defaults or a live backend.

- R27. Session effects now belong to Flux 2 SessionMiddleware, replacing SessionController. Containers/platform lifecycle hooks dispatch typed requests through the scoped cached session store. Preserve consent, synchronous duplicate guards, submitted-draft snapshots, latest endpoint selection before SDK suspension, authoritative streaming/Stop, generation-based stale-result rejection and deterministic local disposal. Store release must not be prevented by suspended SDK work. SettingsController remains unchanged. macOS app automation is temporarily paused by user request; package tests, iOS automation and native builds remain allowed.

## Assumptions
- Confirmed: Pi Studio is native macOS; Pi Pocket is the longer-term iOS controller. The initial SDK proof kept the existing iOS 26.1 target. The shared-package follow-on adds native macOS 26 support without removing iOS.
- A local v2 Pi Server and a configured text-capable model are available for a controlled smoke test; the MVP does not launch or install the server.
- A simple native layout is sufficient. Any UI mockup/approval workflow required by the implementation environment occurs before production UI changes, not as extra product scope.
- The original MVP used a development-only endpoint; the settings follow-on supersedes that restriction. The working directory remains development configuration.
- Confirmed: UserDefaults is sufficient for this non-secret setting, persisted per app installation without cross-device sync. The service protocol keeps persistence replaceable and mockable.
- Confirmed: use a small native settings sheet/form opened from the session screen on both macOS and iOS. Detailed layout approval remains part of the UI implementation workflow. Do not add the deferred Router dependency. (Superseded: the later [Router integration](docs/router-integration/REQUIREMENTS.md) follow-on added released Router 2.0.0.)
- Explicit test/development configuration overrides remain deterministic; automated tests never inherit personal saved settings.

## Implementation Plan
### 1. Confirm Target and Development Wiring
Description: Resolve the platform question before modifying targets. Record the toolchain/deployment baseline, local SDK checkout/revision, server endpoint and demo directory configuration. Establish the agreed app target and local PiSDK package dependency without changing existing targets silently. Verify a clean app build and SwiftPM scaffold build; document how to reproduce them. No networking behavior is claimed yet.

### 2. SDK Connection and Demo Session
Description: Depends on slice 1. Implement the minimal v2 models, configurable WebSocket transport, initialization/controller handling, bounded correlated requests and session creation in the SDK. Provide asynchronous state observation and deterministic disposal without SwiftUI dependencies. Validate the supported models against shared valid/malformed fixtures and test successful initialization, denied access, creation failure, deadlines and stale callbacks with a fake transport. Prove session creation against an isolated loopback server before UI integration.

### 3. SDK Streaming and Stop
Description: Depends on slice 2. Add prompt admission, ordered session projection, incremental assistant text, authoritative run completion and abort for one session. Test two sequential turns, stop with retained partial output, rejection versus uncertain outcomes, malformed required data, unexpected disconnect and disposal during streaming. Use bounded buffering and explicit failure; do not add reconnect, steering or dialog interaction. Verify the SDK package independently of the app.

### 4. Minimal SwiftUI Screen
Description: Depends on slice 3. Implement the single-window native screen using only public PiSDK operations and projections. Add connection/generation status, transcript, input, Send/Stop, Disconnect and visible errors, including the active-run disconnect warning. Keep duplicate submissions disabled and drafts app-owned. Verify screen/action states with injected SDK-facing test doubles and native UI tests; no live model is needed for these tests.

### 5. Real-Pi Acceptance and Handover
Description: Depends on slice 4. Run the acceptance flow against a temporary local server and isolated demo directory, then verify failure paths and repeated connect/disconnect teardown. Explicitly close smoke-test runtimes and stop test-owned server processes. Run SDK tests, app unit/UI tests and the agreed native build. Record reproducible launch instructions, package revision, retained-runtime cleanup, supported operations and deferred dialog/reconnect limitations. Do not mark the full production Swift SDK slice complete or publish anything.

### 6. Shared Flux Session Feature
Description: Extract a local PiUI Swift package, depend on pinned Flux, and move app-owned state into a tested Flux reducer. Keep SDK authority, consent, action guards, draft retention, stale callback handling and disposal behavior unchanged. Provide pure value/callback components with a container that bridges the session store and injected dependencies. Verify reducer transitions using FluxTestStore and lifecycle regressions with injected connections.

### 7. Native macOS Shell
Description: Depends on slice 6. Build the shared session feature in the existing iOS app and a native macOS application using thin platform shells. Preserve the approved screen without adding navigation or redesigning it. Verify native Debug/unit/UI and Release builds on both platforms; keep iOS background disposal and avoid disconnecting when macOS merely loses focus.

### 8. Reproducible Test Pipeline
Description: Configure worktree-safe local SDK preparation and pinned Flux resolution, package unit tests, separate native app unit/UI suites and Release builds. Document commands and run suites against injected connections. Keep isolated loopback and real-model acceptance explicit; no automatic suite may take control of a live backend. Real-model acceptance from slice 5 remains outstanding unless separately performed.

### 9. Persisted Endpoint Settings Vertical Slice
Description: Deliver one end-to-end feature, not separate infrastructure/UI horizontal slices. Build on the existing PiUI/Flux/FactoryKit architecture; slices 1–8 remain historical MVP scope and pending real-model acceptance is not a prerequisite. The persistence, next-connection policy and native sheet/form approach are confirmed; approve the detailed layout before production UI changes. Work test-first in small increments through SettingsFeature, the injectable endpoint-settings service and UserDefaults adapter, the effect owner and scoped registrations, SettingsContainer/value-callback components, and the session-screen entry. Update connection wiring so the session middleware consumes the latest successfully saved endpoint on the next explicit Connect without affecting active/in-flight connections or the working directory. Completion requires the R20–R26 acceptance cases, isolated relaunch persistence on both platforms, and existing PiUI, native unit/UI and Release-build suites passing. Document the default and next-connection policy. Do not add extra settings, router integration, automatic reconnect or live-model tests.

## Open Questions
None.
