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
