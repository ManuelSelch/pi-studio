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
- Contexts keep controllers, SDK projections, XCTest selectors, native-platform
  differences, pending tasks and cleanup out of scenarios.
- Drivers and fixtures are test-only. Production code has no dependency on them.

## Integration driver

[PiIntegrationDriver](../Packages/PiUI/Tests/PiUITests/Support/PiIntegrationDriver.swift)
drives the real SessionController, Flux store and reducer. Only the PiDemoConnection
boundary is stubbed by default; assertions inspect app-observable state rather than
the stub. Fixture assertions separately verify received requests and disposal.

```swift
try await PiIntegrationDriver.run { app in
    try await app.session.connect()
    try await app.chat.sendPrompt("Say hello")
    await app.server.receivedPromptsShouldBe(["Say hello"])
    app.chat.draftShouldBe("")
}
```

`sendPrompt` awaits admission, **not response completion**. The stub-backed helper
accepts that admission automatically. To inspect a pending admission or inject
failure, use `enterDraft` / `beginSend`, then `server.acceptSend`,
`rejectSend` or `loseSendReceipt`. Connection tests similarly use
`beginConnect` and explicit fixture acceptance/rejection.

`run` disconnects and joins pending tasks on both success and thrown failure.
Projection waits have a four-second deadline, identify the awaited condition and
report the scenario's source location. SDK calls retain their own deadlines.

The same driver source is compiled into SwiftPM and both native unit-test targets.
Explicit `run(configuration: ...)` uses the real SDK transport instead of a stub;
only the opt-in loopback test supplies configuration. Normal suites never contact
the development backend. The host loopback script owns server/runtime cleanup.

## UI driver

[PiUIDriver](../pi-studioUITests/Support/PiUIDriver.swift) translates the vocabulary
into actual XCTest taps, typing, dialogs and accessibility assertions. It never
reads the controller, Flux store or SDK state.

```swift
let app = PiUIDriver.launch(for: self)
app.session.connect()
app.chat.sendPrompt("Say hello")
app.chat.waitForReply(1)
app.session.waitUntilReady()
app.chat.replyShouldBe(1, "Hello from the demo. This reply is streaming a little at a time.")
```

The root registers app termination with XCTest teardown and selects portrait on
iOS. Named send-outcome options hide debug launch arguments. The context hides
macOS sheets versus iOS alerts and native static-text representation. Assertions
forward file/line to the scenario. Reply handles are semantic turn numbers, not
accessibility identifiers.

Keep integration and UI implementations independent: their boundary, scheduling
and assertion mechanisms differ. Share vocabulary where behavior matches; do not
force a generic protocol or expose framework objects just to reuse test code.
Reducer unit tests intentionally continue to use FluxTestStore directly.

Settings UI scenarios use a unique `PiStudio.UITests.*` UserDefaults suite passed
through debug-only launch arguments. Initial launch resets only that suite;
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
   controller integration, received requests only for explicit fixture checks.
5. Never hide a defect by changing state directly to satisfy an app assertion.
