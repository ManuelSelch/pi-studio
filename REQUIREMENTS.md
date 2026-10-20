# Pi Studio Minimal MVP — Requirements

## Goal
Prove that a native SwiftUI application can use PiSDK to connect to Pi Server, create one isolated session, exchange streaming text messages, stop a response and disconnect cleanly. This is the first small SDK-backed vertical slice toward a native desktop replacement for Pi Chat, not a full chat application or a claim of complete Swift SDK support.

## Scope
### In Scope
- One native SwiftUI window with connection status, Connect/Disconnect, a plain-text transcript, a message field, Send, Stop and a visible error area.
- A fixed development endpoint and a dedicated server-side demo working directory, supplied through development configuration rather than a settings UI.
- One dedicated session per successful explicit connection, created only after v2 initialization and controller admission succeed.
- The minimal reusable Swift SDK implementation required for this flow, developed in the existing Pi SDK package rather than inside the app.
- Deterministic SDK/app tests and a controlled real-Pi smoke test.
- Provisional macOS-first delivery, subject to the platform question below.

### Out of Scope
- Replacing Pi Chat in full, a separate mobile controller, distribution or App Store submission.
- Session browsing, opening saved history, multiple sessions/windows, project navigation and persistent app state.
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

## Assumptions
- Pi Studio is the desktop app described in the conversation, so macOS is the proposed first target. The supplied Xcode project currently targets iPhone/iPad only (iOS deployment target 26.1); this discrepancy needs confirmation before target changes.
- A local v2 Pi Server and a configured text-capable model are available for a controlled smoke test; the MVP does not launch or install the server.
- A simple native layout is sufficient. Any UI mockup/approval workflow required by the implementation environment occurs before production UI changes, not as extra product scope.
- Development configuration can supply the endpoint and an isolated working directory. No runtime configuration screen is needed.

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

## Open Questions
1. Should this first Pi Studio MVP target macOS, as its desktop role suggests, or keep the existing iOS Simulator target for the initial SDK proof?
