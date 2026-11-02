# Semantic test drivers

Tests describe intent; drivers translate that DSL into actions, waits and assertions.
Use Swift **lowerCamelCase**, not C# PascalCase or Given/When/Then.

## Layers

- **Scenario → root driver → feature driver → shared context → system under test.**
- `app.session` owns connection, consent, status, errors and disconnect.
- `app.chat` owns prompts, drafts, streaming replies, Stop and transcript assertions.
- `app.settings` owns opening/editing/saving/cancelling endpoint settings. UI tests
  also assert rendered validation, endpoint values and connection details.
  `app.relaunch()` reuses the isolated defaults suite to verify persistence.
- Integration-only `app.server` controls the isolated SDK-facing fixture. It is not
  an application action and is only usable in the default stub-backed mode.
- Contexts keep stores, middleware, SDK projections, XCTest selectors, native-platform
  differences, pending tasks and cleanup out of scenarios.
- Drivers and fixtures are test-only. Production code has no dependency on them.

## Integration driver

[PiIntegrationDriver](../Packages/PiUI/Tests/PiUITests/Support/PiIntegrationDriver.swift)
dispatches request actions through the real Flux store, SessionMiddleware and reducer. Only the PiDemoConnection
boundary is stubbed by default; assertions inspect app-observable state rather than
the stub. Fixture assertions separately verify received requests and disposal.

```swift
try await PiIntegrationDriver.run { app in
    try await app.session.connect()
    try await app.chat.sendPrompt("Say hello")
    await app.server.receivedPromptsShouldBe(["Say hello"])
    app.chat.clearInstructionShouldBe("Say hello")
    app.chat.consumeClearInstruction()
    app.chat.clearInstructionShouldBe(nil)
}
```

`sendPrompt` awaits admission, **not response completion**. The stub-backed helper
accepts that admission automatically. To inspect a pending admission or inject
failure, use `beginSend(text)`, then `server.acceptSend`, `rejectSend` or
`loseSendReceipt`. `submit(text)` exercises rejected/unavailable submissions.
Message typing is UI-local; integration tests assert snapshot/clear contracts,
not a simulated Flux draft. UI tests retain `enterDraft` and `draftShouldBe`.
Connection tests similarly use
`beginConnect` and explicit fixture acceptance/rejection.

`run` dispatches disconnect and awaits disposal settlement on both success and thrown failure.
Middleware owns SDK tasks and streams; Flux `finish()` alone does not drain them.
Store release tests also verify disposal during pending Connect/Send without retaining a concrete store.
Projection waits have a four-second deadline, identify the awaited condition and
report the scenario's source location. SDK calls retain their own deadlines.

The same driver source is compiled into SwiftPM and both native unit-test targets.
Explicit `run(configuration: ...)` uses the real SDK transport instead of a stub;
only the opt-in loopback test supplies configuration. Normal suites never contact
the development backend. The host loopback script owns server/runtime cleanup.

## UI driver

[PiUIDriver](../pi-studioUITests/Support/PiUIDriver.swift) translates the vocabulary
into actual XCTest taps, typing, dialogs and accessibility assertions. It never
reads middleware, Flux store or SDK state.

```swift
let app = PiUIDriver.launch(for: self)
app.session.connect()
app.chat.sendPrompt("Say hello")
app.chat.waitForReply(1)
app.session.waitUntilReady()
app.chat.replyShouldBe(1, "Hello from the demo. This reply is streaming a little at a time.")
```

`app.chat.stop()` sends a real Escape key on macOS and taps the running-state
stop icon on iOS. Return, Shift+Return, caret/selection/undo and paste helpers own
native events; paste restores the prior clipboard. macOS scenarios are compile-only
while automation is paused. iOS `pressSoftwareReturn` taps the software Return key;
`typeText` newline events do not prove physical hardware-keyboard behavior.
`delayedAdmission` uses only the injected debug fixture, never a live server. The working-response scenarios use a timed debug fixture that emits separate assistant fragments with an active gap simulating a tool call; it does not execute or inspect a real tool.

The root registers app termination with XCTest teardown before launching and selects
portrait on iOS. macOS UI-test launches pass `-ApplePersistenceIgnoreState YES` to
ignore saved window restoration state, which can otherwise leave a running app
without a workspace window. Normal app launches retain their restoration behavior.
`MacStartupUITests` covers shared launch/relaunch with usable workspace controls;
launch/appearance tests also assert window/control readiness before capturing.
On macOS, shared launch/relaunch records app state, window count,
frontmost application/PID and launch arguments as text in the test log and retained
xcresult attachments. Readiness checks allow up to five seconds each for foreground
state, a window and the Settings control; failure also retains the accessibility
hierarchy. Both initial launch and relaunch call XCTest's `activate()`. These
diagnostics do not capture screenshots or fix window presentation. Named send-outcome options hide debug fixture configuration.
The context hides macOS sheets versus iOS alerts and native static-text
representation. Assertions forward file/line to the scenario. Reply handles are semantic turn numbers, not
accessibility identifiers.

Keep integration and UI implementations independent: their boundary, scheduling
and assertion mechanisms differ. Share vocabulary where behavior matches; do not
force a generic protocol or expose framework objects just to reuse test code.
Quick-switcher search/filter and result metadata are covered by `QuickSwitcherModelTests`;
rejected opens and parking/resuming saved sessions are covered by `WorkspaceMiddlewareTests`.
Settings endpoint changes during a live session, session archiving and quick-switcher
session deduplication also have app-boundary scenarios. Duplicate send admission,
whitespace-only submissions, identical-send clear instructions, formatted prompt
payloads and stopped-response retention are covered by `SessionLifecycleTests`.
`MarkdownPromptWhitespaceTests` checks indentation preparation, and
`TranscriptPresentationTests` checks response-label grouping.
These checks do not prove that the corresponding results or errors render correctly,
that iOS Later or macOS archive controls are reachable, or that repeated native Return,
whitespace-only drafts and repeated identical local-draft clearing work in the UI.
Nor do they prove rendered indentation, per-response label grouping, or that a stopped
Markdown response remains readable after disconnect.
Reducer unit tests intentionally continue to use FluxTestStore directly.

Settings UI scenarios use a unique `PiStudio.UITests.*` UserDefaults suite passed
through the debug-only `PI_UI_SETTINGS_SUITE` launch environment variable. All
fixture options use `PI_UI_*` environment variables rather than command-line flags,
which interfered with macOS window presentation in startup probes.
Initial launch resets only that suite;
relaunch preserves it, and teardown resets it again. All launches use injected
connections. Integration scenarios use an in-memory settings service and record
connection-builder endpoints separately from app assertions. Production adapter
unit tests own and clean unique `PiStudio.Tests.*` suites.
Launch/appearance screenshot tests are platform harness checks, not chat workflows.

## Adding coverage

1. Express the next behavior in a short scenario using an existing feature driver.
2. Add the smallest semantic action/assertion if needed.
3. Implement selectors, SDK calls and bounded waits only in that boundary's driver.
4. Assert at the boundary under test: rendered UI for UI tests, app state for
   middleware integration, received requests only for explicit fixture checks.
5. Never hide a defect by changing state directly to satisfy an app assertion.
