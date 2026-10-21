# Pi Studio compact workspace — implementation record

Slice status for [REQUIREMENTS.md](./REQUIREMENTS.md). Branch `feat/layout`, based on
`main` @ `ddbcfe2` (the uncommitted middleware refactor was intentionally not used;
see "Reconciliation" below).

## Slice 1 — Project browser and compact workspace shell

Delivered:

- `Projects` slice: `ProjectGroup`/`SessionActivity` domain types, `ProjectListModel`
  grouping (Quick Chats first, repository/worktree grouping, saved history, unsaved
  and running runtimes, archived history hidden), `ProjectsFeature`, `ProjectsController`
  (browsing, explicit create/open/attach, isolated per-session drafts, unknown-outcome
  blocking).
- `SessionController.attach(connection:session:)` plus `SessionFeature.attached`, so the
  conversation adopts the workspace connection instead of opening its own.
- `Workspace` slice: `WorkspacePresentation`/`WorkspaceActions`, `WorkspaceSidebar`
  (search, Quick Chats first, projects and history, activity indicators, connection
  footer, browsing error banner), `WorkspaceConversation`, `WorkspaceEmptyState`,
  `MacWorkspaceScreen` (split view, no tab strip yet), `PhoneWorkspaceScreen`
  (NavigationStack, native back, connection/settings toolbar in a pushed conversation),
  `WorkspaceContainer` (consent, settings sheet, presentation mapping).
- App shell now hosts `WorkspaceContainer` on both platforms with one shared connection.
- UI fixture `UITestConnection` is a `PiSessionConnection`; UI drivers gained
  `UIProjectsDriver`, browsing scenarios and settings scenarios for the new shell.

Verification (all on this worktree's isolated DerivedData and simulator):

- PiUI package: 39 tests pass (`pipeline_run piui`), including 8 project/browsing tests.
- iOS unit: 2 tests pass; iOS UI: 14 executions, 0 failures (`ios-ui`), including
  connect-without-creating, Quick Chats, running-session attach, rejected open, streaming
  with Stop, unknown/rejected send, and settings persistence.
- macOS Release: universal build succeeds (`macos-release`).
- macOS UI automation stays paused by user request, so Mac tab/split-view behaviour is
  only build-verified so far.

## Slice 2 prerequisite — Swift SDK switching safety (merged)

The pi-chat repository's `packages/pi-sdk` delivers R11 items a–c without per-session
streaming. It is **merged into pi-chat `main`** (`8364263`, merge of `c7ef9a0` and
`3ed2b73`; 35 Swift and 155 TypeScript tests pass on the merged tree), so this branch and
Pi Studio `main` both build against the released checkout with no `PI_SDK_PATH` override:

- Bounded keyed request correlation (max 8 in flight) replaces the single pending slot, so
  a selection and a mutation can overlap without a false identity violation.
- Selection is refused only while another selection is in flight; an admitted run's
  settlement deadline no longer blocks switching.
- `send`/`stop` and the run-settlement deadline are bound to the runtime they were issued
  for, so a late result cannot settle against a later tab.
- `PiSessionEvent.closed`/`.replaced` report identity changes of the observed runtime, and
  a replacement swaps the open-session inventory entry atomically.

Verified: 34 Swift SDK tests pass (5 new switching scenarios, each red before the change;
including the loopback test with repository Node deps installed), 155 TypeScript SDK tests
pass, and PiUI's 39 package tests plus both Pi Studio iOS builds pass against this branch.

Landing order and the reconciliation work needed before this branch can merge are planned in
[MERGE_PLAN.md](./MERGE_PLAN.md).

## Slice 2 — Independent sessions and Mac tabs

SDK prerequisites came first (pi-chat, merged into its `main` as `8364263`):

- `c7ef9a0` — bounded keyed request correlation, selection never blocked by an admitted
  run, send/stop bound to their session, `PiSessionEvent.closed`/`.replaced`.
- `3ed2b73` — `sessionEvents()` declared on `PiSessionConnection`, so the workspace
  observes identity changes through the contract it actually holds.

Delivered in `feat/layout`:

- `Workspace/Domain/OpenSession.swift`: a tab is keyed by server scope plus saved
  session path (else the runtime identity), so a runtime replacement keeps the tab.
- `WorkspaceFeature` now owns `openSessions`, `selectedSessionId` and per-tab local
  state (draft, follow-tail, reading anchor, unread). Opening the same history/runtime
  selects its existing tab; new sessions append so tabs never jump; closing a tab
  selects the neighbour on the right, else the left, and last-tab closure leaves an
  empty workspace with the connection intact.
- `WorkspaceController` serializes selection work in one loop: a switch is allowed while
  another session generates, an in-flight attach whose choice was superseded is
  discarded instead of rendered, and the loop re-attaches until the observed runtime is
  the selected one. Opens reuse an already-open tab without asking the server again.
  `closeSession` performs no server call at all, and `SessionController.detach()` stops
  observing a session without touching the server or the transport.
- Server identity events drive tabs: `closed` removes the tab and selects the neighbour;
  `replaced` keeps the tab, its key, draft and order and swaps its runtime identity.
  Tab status comes from the inventory, never a timer or a second transcript.
- Mac UI: `SessionTabStrip`/`SessionTab` (status, label, unread marker, per-session
  close, selected tab scrolled into view) inside `WorkspacePane`, which paints its own
  surface; the phone still renders no tab strip.
- `SessionTranscript` no longer scrolls on every message change: it follows the tail
  only while the reader is at the tail, and each tab restores its own reading position.

Verification (this worktree's DerivedData and simulator):

- PiUI: 57 tests pass — 11 workspace reducer tests, 8 open-tab scenarios and the
  off-screen render. The tab scenarios were written first and failed until the loop,
  draft ownership and activity mapping were right.
- iOS unit 2 pass; iOS UI 14 executions, 0 failures; macOS unit 2 pass; macOS Release
  builds; the SDK's Swift suite 35 pass and TypeScript suite 155 pass.
- macOS UI automation stays paused by user request. `MacWorkspacePaneRenderTests`
  renders the real pane through a hosting window instead of driving a window; it caught
  two real problems (an `ImageRenderer`-only render fakes a blank layout, and the
  conversation header was relying on a parent's background).

Deliberate slice-2 limits:

- Per-session request/error state is not kept per tab yet: a send failure is shown for
  the selected tab and cleared on switch. Slice 4 owns per-session attention/activity,
  and slice 5 owns pending-request identity.
- `unread` exists as tab state but nothing sets it yet (slice 4).
- No iPhone overview (slice 3), no numbered shortcuts, no persistence across launches.
- Mac scroll-gesture behaviour is verified by build and manual/off-screen review only
  while app automation is paused.

## Reconciliation with `main` (Flux 2 middleware, slices, Container DI)

`main` moved three times while slices 1–2 were in flight; the merge is recorded in
[MERGE_PLAN.md](./MERGE_PLAN.md) and landed as `9a04e86` + `b1929b1` + `54b8c90`.

What the reconciled code looks like now:

- `Workspace/{WorkspaceContainer.swift, App/WorkspaceFeature.swift, Domain/OpenSession.swift,
  Middleware/WorkspaceMiddleware.swift, UI/*}` and `Projects/{App,Domain}` follow the
  `Session`/`Settings` slice layout.
- `Session` and `Workspace` stay separate features joined by one injected `SessionTransport`
  (`Session/App/SessionTransport.swift`). Flux 2 has no cross-store dispatch, so
  `WorkspaceMiddleware` owns the connection, publishes it, and tells the conversation store
  which runtime it attached; `SessionMiddleware` filters projections by that identity, which is
  what makes a superseded attach harmless. Both middlewares take their dependencies by
  constructor injection, because a property wrapper resolves outside the creating scope.
- `SessionFeature`/`SessionMiddleware` keep the transcript, send/stop admission and prompt
  errors; `WorkspaceFeature`/`WorkspaceMiddleware` own connection, catalogue, session events,
  serialized selection and the open tabs. `SessionController`, the `SessionDependencies` class,
  `SessionContainer` and `SessionConfiguration` are gone; their tests were ported.
- Drafts, follow-tail and the reading anchor live per tab in the workspace store; the composer
  edits the selected tab's text and only clears it once a send is admitted.
- `detachRequested` keeps the last-known conversation: a disconnect disposes local networking
  only (R14), which the retained-transcript UI tests assert.

Verification after the merge:

| Suite | Result |
| --- | --- |
| PiUI package | 72 tests pass (ported middleware/lifecycle/reducer tests + tab scenarios + off-screen Mac pane render) |
| iOS unit | pass |
| iOS UI | 22 executions, 0 failures — includes the existing multiline composer and settings suites plus workspace browsing |
| macOS unit | pass |
| macOS Release | builds |
| macOS UI | **Not usable in this environment**: the runner reports `Not authorized for performing UI testing actions` and an empty accessibility tree even though the app renders correctly (verified by capturing the window with `screencapture -l`). Mac composer behaviour is covered in-package instead (`MacComposerTypingTests`, `MacWorkspaceComposerTests`). |

Composer fixes on top of the merge (`844c495`, `2f84e26`, `4488e93`, `b97d30c`):

- A session that is not idle locks the composer; the Mac editor now dims, the row states the
  reason, and a stale render can no longer revert typing.
- A window that opens behind another app receives no keystrokes, so the editor claims the caret
  when its window becomes key, and the UI test driver requests activation after launch.

Deliberate limits carried forward: per-session request/error state and populated `unread`
arrive with slice 4, the iPhone overview with slice 3, and no launch persistence.

## Notes and follow-ups

- Deliberate slice-1 limits: no session tab strip, no Activity section, no Needs you
  popup and no numbered shortcuts. Each is planned in slices 2–5.
- The browsing error surfaces both in the sidebar and in the empty state.
- `scripts/simulator-destination.sh` (per-worktree Simulator) was adopted from the
  unmerged `feat/pocket` work after a shared-Simulator collision made one UI run pass
  against another worktree's installed app; the same script fixes that class of failure.
- Reconciliation: `feat/pocket` also contains this browsing feature built on the older
  controller baseline. Only its grouping/model and UI-fixture knowledge were reused;
  `docs/pi-pocket/REQUIREMENTS.md` slice 2 (foreground recovery) and slice 3 (steering,
  structured questions) remain unmerged and unstarted here.
