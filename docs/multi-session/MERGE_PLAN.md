# Pi Studio — merging `feat/layout` into `main`

Planning document. Nothing here is executed yet; `feat/layout` and `main` are both untouched.
Every claim below was measured: a trial merge (`git merge feat/layout --no-commit`, then
aborted) in `~/.worktrees/pi-studio/merge-layout-reconcile`, plus reference counting over both
trees.

Revision 2 — rewritten after `main` moved again (`7e98b9f`, `a7bb25b`).

## What changed on `main` since revision 1

Revision 1 planned against `main` @ `8ef722b`. `main` is now `a7bb25b`:

- **`7e98b9f refactor: use dependency injection, regroup features, migrate controller to
  middleware`** — `SettingsController` is **deleted**; Settings is now a Flux 2 feature
  (`Settings/{App/SettingsFeature, Middleware/SettingsMiddleware, SettingsContainer}`) with
  `opened`/`cancelled`/`draftChanged`/`saveTapped`/`saved`/`saveFailed` actions. All PiUI code is
  regrouped into slices (`Session/{App,Middleware,UI}`, `Settings/{App,Domain,Infra,Middleware,UI}`,
  container at the slice root) and the app resolves stores through
  `@Injected(\.…)/@InjectedObject(\.…)` with `extension Container` factories.
- **`a7bb25b fix: restore observed session and settings store wiring`** — the wiring fix that
  made the store-based settings flow work.
- **`SessionDependencies` as a class is gone**: `Session/App/SessionDependencies.swift` now
  declares `extension Container { sessionStore, settingsStore, sessionConfiguration,
  makeConnection, endpointSettingsService }`, `endpointSettingsService` is overridden in the app
  with `.onDebug(factory:)`, and `pi_studioApp` no longer holds a `@State` dependencies object.
- Still true from revision 1: Flux 2 `SessionMiddleware` owns the connection and the SDK effects,
  `SessionController` is deleted, and the multiline Mac composer (`MacMessageEditor`,
  `MacComposerCommand`, `MultilineComposerUITests`) owns its draft in view state with
  `clearDraftMatching`.

## Why this still cannot be a plain merge

The trial merge against the new `main` conflicts in the same 10 files, with two now
`modify/delete`:

```
modify/delete: Packages/PiUI/Sources/PiUI/App/SessionController.swift      (feat/layout only)
modify/delete: Packages/PiUI/Sources/PiUI/App/SessionDependencies.swift    (moved to Session/App as a Container extension)
content:       Packages/PiUI/Sources/PiUI/Session/App/SessionFeature.swift
content:       Packages/PiUI/Sources/PiUI/Session/UI/SessionScreen.swift
content:       Packages/PiUI/Tests/PiUITests/Middleware/SessionLifecycleTests.swift
content:       Packages/PiUI/Tests/PiUITests/Support/PiIntegrationDriver.swift
content:       pi-studio/UITestConnection.swift
content:       pi-studio/pi_studioApp.swift
content:       pi-studioUITests/Support/PiUIDriver.swift
content:       pi-studioUITests/pi_studioUITests.swift
```

Git handled the file moves well: the only stale paths left in the merged tree are the two
`App/…DU` files, and everything else landed at `main`'s slice layout. The real problem is not the
text conflicts, it is three surviving API mismatches that only show up at compile time:

| `feat/layout` uses | occurrences | `main` has instead |
| --- | --- | --- |
| `SessionController` (`attach`, `detach`, `send`, `stop`) | 13 in 7 files | `SessionMiddleware` owning the connection + `SessionFeature` `*Requested`/`*Finished` actions |
| `SessionDependencies` (class, instance scope) | 12 in 5 files | `extension Container` + `@InjectedObject(\.sessionStore)` |
| `SettingsController` / `settingsController()` / `settings.open` | 17 + 7 + 12 in 7 files | `SettingsFeature` actions + `@InjectedObject(\.settingsStore)` |

## Work inventory (measured)

| Layer | Size | Fate |
| --- | --- | --- |
| `Workspace/{Domain/*, UI/Components/*}`, `Projects/{App, Domain}/*` | 663 lines | **Survives essentially unchanged** (plain values, no SDK/DI) — re-home into the slice layout |
| `Workspace/App/WorkspaceController.swift` | 327 | **Replaced** by `WorkspaceMiddleware` |
| `Workspace/App/WorkspaceFeature.swift` | 148 | Extended with `main`'s request/finish vocabulary + selected conversation state |
| `Workspace/UI/Containers/*` + `App/SessionDependencies.swift` | 281 | Re-platformed onto `@InjectedObject` + `SettingsFeature` |
| `Support/WorkspaceIntegrationDriver.swift` + `Workspace/*` tests | ~313 + tests | Ported to the middleware store |
| `main`'s UI tests that must keep passing | 597 | `MultilineComposerUITests`, `SettingsUITests`, `pi_studioUITests`, `PiUIDriver` |

## Target architecture (recommended)

One workspace store, one middleware, no cross-store dispatch, `main`'s conventions:

- **`Workspace/{App/WorkspaceFeature.swift, Middleware/WorkspaceMiddleware.swift,
  Domain/OpenSession.swift, UI/…, WorkspaceContainer.swift}`** — the workspace slice mirrors the
  `Session`/`Settings` layout exactly, including the container at the slice root.
- **`WorkspaceFeature`** owns connection state, catalogue, ordered open sessions, the selected
  id, per-tab local state, **and the selected session's conversation state** (projection,
  sending/stopping/error). Actions follow `main`: `connectRequested`, `openRequested`,
  `selectRequested`, `closeRequested`, `sendRequested`, `stopRequested`, `disconnectRequested`
  plus the `*Finished`/`failed`/`projectionChanged` results.
- **`WorkspaceMiddleware`** (modelled on `SessionMiddleware`) owns the single
  `any PiSessionConnection` and every SDK effect: connect, catalogue/state/session-event
  observation, open, attach, serialized switch, `message.send`, `run.abort`, disconnect. It keeps
  the reservation pattern (reducer reserves synchronously, middleware generation-checks) and the
  guarantee that a superseded in-flight selection is re-attached rather than trusted.
- **DI**: replace the `SessionDependencies` class with `extension Container { workspaceStore }`,
  a `@InjectedObject` container, and `.onDebug(factory:)` overrides in `pi_studioApp` for the
  `--ui-testing` connection and settings suite.
- **Settings**: `WorkspaceContainer` dispatches `SettingsFeature` actions and observes
  `settingsStore.state.isPresented`; no controller.
- **Composer**: keep `main`'s `MacMessageEditor`/`MacComposerCommand`/iPhone field and the
  stop/send affordances. Only the draft source changes — a `Binding` to the selected tab's draft
  instead of view `@State` + `clearDraftMatching`; "retain on rejection, clear on admission" stays
  as tested.
- **Retire** `SessionFeature`/`SessionMiddleware`/`SessionContainer`/`SessionController`; their
  tests are **ported, not deleted** (`SessionMiddlewareTests` + `SessionLifecycleTests` →
  `Workspace/Middleware` tests with the same scenario names).

Alternative (not recommended): keep two stores and inject the workspace connection into a reduced
`SessionMiddleware`. Same coupling, more indirection, and one session's state split again.

## Ordered plan (each step ends green)

1. **Reconcile worktree.** Reset the scratch worktree to the new `main`, merge `feat/layout`
   `--no-commit`, and resolve to the target: drop `App/SessionController.swift` and
   `App/SessionDependencies.swift`, keep the whole `Projects/` + `Workspace/` slices, keep
   `main`'s composer/middleware/settings files. Move `Workspace/{Domain,UI,App}` into the slice
   layout and place `WorkspaceContainer.swift` at the slice root.
2. **DI + settings re-platform** (smallest step that compiles): `Container` factory for the
   workspace store, `@InjectedObject` container, `SettingsFeature` dispatch/observe. Delete the
   last `SettingsController` references.
3. **Workspace feature shape.** Add the `*Requested`/`*Finished` vocabulary and the selected
   conversation state; port the reducer tests from `SessionFeatureTests` and the existing
   `WorkspaceFeatureTests` before touching effects.
4. **`WorkspaceMiddleware`.** Move every SDK effect out of `WorkspaceController` and
   `SessionMiddleware` into it, porting `SessionMiddlewareTests`/`SessionLifecycleTests`
   scenarios, then delete both old files.
5. **Selection + tab semantics.** Port the serialized selection loop, late-result rejection and
   the `sessionEvents` close/replace handling; keep the eight `WorkspaceTabsTests` scenarios and
   `lateSelectionResultCannotOverwriteTheNewestChoice` green.
6. **UI re-platform.** `WorkspacePane`/`SessionTabStrip` on `main`'s composer, per-tab draft
   binding, per-session follow-tail/anchor; keep the off-screen `MacWorkspacePaneRenderTests`
   PNG review as the Mac layout gate while app automation is paused.
7. **Shell, fixtures, drivers, UI tests.** `pi_studioApp` (Window + one store + `onDisappear`
   disconnect), `UITestConnection` (merge my catalogue/`PiSessionConnection` rewrite with
   `main`'s `delayedAdmission` flag), `PiUIDriver`, `UIProjectsDriver`, `pi_studioUITests`,
   `SettingsUITests`, and `main`'s `MultilineComposerUITests` must all pass in the same run.
8. **Verify and merge.** Run the matrix below, review commit by commit (~8 reviewable commits,
   not one dump), then merge into `main` and remove the scratch worktree.

## Verification matrix for the merge

| Suite | Command | Gate |
| --- | --- | --- |
| Package | `pipeline_run piui` | All PiUI tests pass: ported middleware tests, workspace reducer tests, tab scenarios, render test |
| iOS unit | `pipeline_run ios-unit` | Pass |
| iOS UI | `pipeline_run ios-ui` | Pass, including `MultilineComposerUITests` + workspace browsing |
| macOS unit | `pipeline_run macos-unit` | Pass |
| macOS Release | `pipeline_run macos-release` | Builds |
| Mac layout | `MacWorkspacePaneRenderTests` PNG review | Tab strip matches revision 4 |
| macOS UI | `macos-ui` | **Paused by user request**; not a merge gate and not claimed |

SDK prerequisite: pi-chat `packages/pi-sdk` switching/identity work is already merged into
pi-chat `main` (`8364263`), so both `feat/layout` and Pi Studio `main` build against the released
`.dependencies/pi-sdk` checkout with no `PI_SDK_PATH` override. Re-verified: 35 Swift + 155
TypeScript tests pass there, and `feat/layout`'s 57 PiUI tests pass against it.

## Decisions to confirm before executing

1. Retire `SessionFeature`/`SessionMiddleware`/`SessionContainer` in favour of one
   `WorkspaceFeature`/`WorkspaceMiddleware` (recommended), or keep two stores?
2. Draft ownership: per-tab draft in the workspace store (recommended, required for tabs) versus
   `main`'s view-owned draft + `clearDraftMatching`.
3. Slice layout: adopt `Workspace/{App,Domain,Middleware,UI}` + `WorkspaceContainer.swift` at the
   slice root to match `Session`/`Settings` (recommended), or keep `Workspace/UI/Containers`.
