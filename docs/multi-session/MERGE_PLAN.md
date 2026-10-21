# Pi Studio — merging `feat/layout` into `main`

Planning document. Nothing here is executed yet; `feat/layout` and `main` are both untouched.
Written after a trial merge (`git merge feat/layout --no-commit`, then aborted) so every claim
below is measured, not assumed.

## Why this cannot be a plain merge

`feat/layout` was deliberately built on `ddbcfe2` (pre-refactor) so slices 1–2 would not fight
in-flight work. `main` has since moved (now `8ef722b`), adding ~1 200 lines:

| `main` added | Effect on the merge |
| --- | --- |
| `Middleware/SessionMiddleware.swift` (165) + `Middleware/SessionMiddlewareTests` (131) + `SessionLifecycleTests` (101) | A **Flux 2 middleware** owns the SDK connection and every session effect |
| Reworked `SessionFeature` (+69/−…) with `*Requested`/`*Finished` actions and request reservations | Replaces `SessionController`'s observable-controller model |
| Deleted `App/SessionController.swift` (−121) | `feat/layout` modified that file → `modify/delete` conflict |
| `MacMessageEditor` (189), `MacComposerCommand` (29), reworked `SessionComposer` (+64), `MultilineComposerUITests` (163) | Multiline Mac composer with view-owned draft + `clearDraftMatching` |
| `SessionConfiguration.swift`, `SessionDependencies.sessionStore`, `SessionContainer` rework | One cached session store per scope with its own middleware |

`feat/layout` adds ~2 600 lines: the Projects slice, the Workspace slice (tabs, selection,
per-session state), `SessionController`, the Mac/iPhone shells and the UI drivers.

A trial merge yields 10 conflicts:

```
modify/delete: Packages/PiUI/Sources/PiUI/App/SessionController.swift
content:       Packages/PiUI/Sources/PiUI/App/SessionDependencies.swift
content:       Packages/PiUI/Sources/PiUI/App/SessionFeature.swift
content:       Packages/PiUI/Sources/PiUI/Components/SessionScreen.swift
content:       Packages/PiUI/Tests/PiUITests/Middleware/SessionLifecycleTests.swift
content:       Packages/PiUI/Tests/PiUITests/Support/PiIntegrationDriver.swift
content:       pi-studio/UITestConnection.swift
content:       pi-studio/pi_studioApp.swift
content:       pi-studioUITests/Support/PiUIDriver.swift
content:       pi-studioUITests/pi_studioUITests.swift
```

The conflicts are symptoms of one real problem: **two competing session owners**. `main`'s
middleware owns the connection and drives `SessionFeature`; `feat/layout`'s `WorkspaceController`
owns the connection and drives `SessionFeature` too. The workspace must own the connection
(it browses, opens and switches several sessions) and `main`'s rule — "SDK effects belong in
Flux 2 middleware, not views or new observable controllers" (R10) — must survive.

## Cross-repo prerequisite — done

PiUI now requires `sessionEvents()` on `PiSessionConnection`. That lives in pi-chat
`feat/sdk-switching`, merged into pi-chat `main` as `8364263` (35 Swift tests, 155 TypeScript
tests pass on the merged tree). `feat/layout` was re-pointed at the released checkout
(`bash scripts/prepare.sh`) and still passes 57 tests, so **no `PI_SDK_PATH` override is needed
for the reconciliation**. Pi Studio `main`'s `.dependencies/pi-sdk` symlink already resolves to
that same checkout.

## Target architecture (recommended)

One workspace store, one middleware, no cross-store dispatch:

- **`WorkspaceFeature`** (from `feat/layout`) owns connection state, catalogue, ordered open
  sessions, the selected id, per-tab local state (draft, follow-tail, reading anchor, unread)
  **and the selected session's conversation state** (projection, sending/stopping/error).
- **`WorkspaceMiddleware`** (new, modelled on `SessionMiddleware`) owns the single
  `any PiSessionConnection` and performs every SDK effect: connect, catalogue/state/session-event
  observation, open, attach, switch, `message.send`, `run.abort`, disconnect. It keeps `main`'s
  reservation pattern: the reducer reserves `*Requested` synchronously, the middleware
  generation-checks and dispatches `*Finished`.
- **`WorkspaceFeature.State`** keeps `feat/layout`'s serialized-selection guarantee (`late
  selection results are discarded`, `the loop re-attaches until observed == selected`) as
  middleware logic with the same tests.
- **`SessionFeature` / `SessionMiddleware` / `SessionContainer` retire.** Their behaviour is
  ported, not dropped: `SessionMiddlewareTests` and `SessionLifecycleTests` become
  `WorkspaceMiddlewareTests` (reservation, generation rejection, cancellation during connect,
  disconnect settlement, uncertain draft retention), and `SessionContainer` is replaced by
  `WorkspaceContainer` + `WorkspacePane`.
- **The composer keeps `main`'s components** (`MacMessageEditor`, `MacComposerCommand`, the
  iPhone `TextField`, stop/send affordances). Only its draft source changes: instead of
  `SessionComposer`'s private `@State` + `clearDraftMatching`, the draft is a `Binding` to the
  selected tab's draft in `WorkspaceFeature`, so each tab keeps its own text and the
  "retain on rejection / clear on admission" behaviour stays exactly as tested.
- **Tab UI, transcript follow-tail and the per-session reading position** carry over unchanged
  in concept; `SessionScreen` keeps `main`'s new parameters plus `feat/layout`'s `showsHeader`
  and `maxContentWidth`.

Alternative if the user prefers two stores (not recommended): keep `SessionFeature` for the
conversation and let the workspace middleware inject its connection into a reduced
`SessionMiddleware`. That is the same coupling with more indirection, and it splits one
session's state across two stores again.

## Ordered plan (each step ends green)

1. **Reconcile branch.** `worktree_create merge/layout-reconcile` from `main` (already created
   for the trial), merge `feat/layout` with `--no-commit` and resolve to the target: keep
   `main`'s composer/middleware files, keep the whole `Projects/` and `Workspace/` slices,
   delete `SessionController.swift` and its tests, and land `SessionFeature` on `main`'s version
   only as an intermediate step so the tree compiles.
2. **Workspace feature shape.** Extend `WorkspaceFeature` to carry the selected conversation
   state and the `*Requested`/`*Finished` action vocabulary; port reducer tests from
   `SessionFeatureTests` (`connectedWithoutSession…`, `changedDraftIsNotClearedByEarlierSend`,
   `staleCallbacksCannotOverwriteDisconnectedState`, …) before touching the middleware.
3. **`WorkspaceMiddleware`.** Move every SDK effect out of `WorkspaceController` and
   `SessionMiddleware` into it; port `SessionMiddlewareTests` + `SessionLifecycleTests` naming
   the same scenarios (`explicitConnectionCannotBeDuplicated`, `disconnectDuringConnect…`,
   `cancelledSendDoesNotResume…`).
4. **Selection semantics.** Port the serialized selection loop and late-result rejection into
   the middleware, keeping the eight `WorkspaceTabsTests` scenarios plus
   `lateSelectionResultCannotOverwriteTheNewestChoice` green against it.
5. **UI re-platform.** `WorkspacePane` + `SessionTabStrip` on top of `main`'s composer;
   draft binding per tab; retain the off-screen `MacWorkspacePaneRenderTests` render as the
   Mac layout gate while app automation is paused.
6. **Shell, fixtures, drivers.** `pi_studioApp` (one window/one store), `UITestConnection`
   (already a `PiSessionConnection`, needs `main`'s new expectations), `PiUIDriver`,
   `UIProjectsDriver`, `pi_studioUITests`, `SettingsUITests`, and `main`'s
   `MultilineComposerUITests` must all pass together.
7. **Verify and merge.** Run the matrix below, review commit by commit (this should land as
   ~7 reviewable commits, not one dump), then merge the reconcile branch into `main` and
   remove the scratch worktree.

## Verification matrix for the merge

| Suite | Command | Gate |
| --- | --- | --- |
| Package | `pipeline_run piui` | All PiUI tests pass, including ported middleware and tab scenarios |
| iOS unit | `pipeline_run ios-unit` | Pass |
| iOS UI | `pipeline_run ios-ui` | Pass, including `MultilineComposerUITests` and workspace browsing |
| macOS unit + Release build | `pipeline_run macos-unit`, `macos-release` | Pass / builds |
| Mac layout | `MacWorkspacePaneRenderTests` PNG review | Tab strip matches revision 4 |
| macOS UI | `macos-ui` | **Paused by user request**; not a merge gate, must stay unclaimed |

## Decisions to confirm before executing

1. Retire `SessionFeature`/`SessionMiddleware`/`SessionContainer` in favour of one
   `WorkspaceFeature`/`WorkspaceMiddleware` (recommended), or keep two stores?
2. Draft ownership: per-tab draft in the workspace store (recommended, required for tabs) versus
   `main`'s view-owned draft + `clearDraftMatching`.
3. Keep the pended `feat/pocket` work in mind: its slice 2/3 (foreground recovery, steering,
   structured questions) stay unstarted; slices 3–5 of this feature (iPhone overview, background
   activity, Needs you) continue on top of the reconciled base.
