# Pi Studio — merging `feat/layout` into `main`

Planning document. Nothing here is executed yet; `feat/layout` and `main` are both untouched.
Every claim below was measured: a trial merge (`git merge feat/layout --no-commit`, then
aborted) in `~/.worktrees/pi-studio/merge-layout-reconcile`, plus reference counting over both
trees.

Revision 3 — decisions confirmed, `Session` and `Workspace` stay separate slices.

## Confirmed decisions

1. **`Session` and `Workspace` remain separate feature slices.**
   - `Session` owns the conversation: transcript, send/stop admission, prompt errors, draft-clear
     signalling.
   - `Workspace` owns navigation and transport: browsing projects and sessions, opening,
     attaching, the open-session tabs, selection, connection lifecycle, and the background
     activity that comes from the server inventory.
2. **The per-tab draft lives in the workspace store** (required by tabs; the composer's draft
   text is bound to the selected tab).
3. **Slice layout matches `Session`/`Settings`**: `App`, `Domain`, `Middleware`, `UI`, with the
   container at the slice root.

## The seam between Session and Workspace

`Session` needs a transport to send and stop and to observe the transcript; `Workspace` owns the
single `PiSessionConnection`. Flux 2 cannot bridge stores: `Middleware`/`StoreHandle` are generic
over one feature and `StoreHandle` is created internally by `FluxStore` (measured in
`Sources/Flux/FluxStore.swift`), so there is no supported cross-store dispatch.

Therefore the connection is published through one injected dependency:

```swift
// Session/App/SessionTransport.swift
@MainActor public final class SessionTransport {
    public internal(set) var connection: (any PiDemoConnection)?   // set by WorkspaceMiddleware
    public internal(set) var generation = UUID()                   // bumped on attach/detach
    public internal(set) var sessionId: String?                    // the observed runtime
}
```

- `WorkspaceMiddleware` writes it (on connect, on each serialized attach/switch, on disconnect)
  and is the only thing that creates or disposes a connection.
- `SessionMiddleware` reads it: on `attachRequested(sessionId:generation:)` it subscribes to
  `connection.states()/projections()`, **ignoring projections whose `session.sessionId` is not the
  expected one** (this is what makes a superseded attach harmless), and its send/stop tasks call
  `connection.send(_:)`/`stop()`.
- Injection uses the same pattern `main` already uses for `endpointSettingsService` in
  `SettingsMiddleware`: `@Injected(\.sessionTransport)`. No cycle: `sessionStore` resolves only
  the transport, `workspaceStore` resolves the transport and the settings store.
- The container bridges the two user-facing signals that cannot be effects either way:
  `WorkspaceContainer` dispatches `attachRequested` into the session store when the selected tab
  changes, and routes the session store's `clearDraftMatching` into the workspace store
  (`draftCleared(matching:)`) so the per-tab draft is only cleared once a send is admitted —
  the same rule `main`'s composer follows today, just with the draft stored one level up.

## Slice responsibilities after the merge

| Concern | After the merge | Today (`main` / `feat/layout`) |
| --- | --- | --- |
| `server.initialize`, catalogue, `session.list.changed` | `WorkspaceMiddleware` | nowhere / `WorkspaceController` |
| Open, attach, serialized switch, late-result rejection | `WorkspaceMiddleware` | `WorkspaceController` |
| `session.closed` / `session.replaced` → tab lifecycle | `WorkspaceMiddleware` + `WorkspaceFeature` | `WorkspaceController` |
| Open-session order, selection, per-tab draft/follow-tail/anchor/unread | `WorkspaceFeature` | `WorkspaceFeature` (survives) |
| Connection consent, endpoint policy, connect/disconnect | `WorkspaceFeature` + settings store | `SessionFeature`/`SessionMiddleware` |
| Transcript, `message.send`, `run.abort`, admission, errors | `SessionFeature` + `SessionMiddleware` | `main` (keeps `*Requested` reservations) |
| Draft text | workspace tab, bound into the composer | view `@State` + `clearDraftMatching` |
| `SettingsController` | dispatching `SettingsFeature` actions | deleted on `main` |

`SessionContainer` retires (the app hosts `WorkspaceContainer`); `SessionScreen`,
`SessionComposer`, `MacMessageEditor`, `MacComposerCommand`, `SessionTranscript` and
`SessionHeader` stay in `Session/UI`, with the composer taking a draft `Binding` instead of its
private `@State`. `SessionMiddleware` keeps everything except connection creation and
`connectDemo`; `SessionConfiguration` loses its consumer in the app path (the workspace reads the
endpoint from the settings store and creates sessions inside a catalogue project) and can be
retired with the demo `connectDemo` app flow, which the SDK still offers for the demo convenience
API.

## Measured merge facts

`main` is `a7bb25b` (`7e98b9f`, `a7bb25b` moved it further than revision 2 recorded):
`SettingsController` deleted, Settings is a Flux feature, PiUI regrouped into slices, and stores
resolve through `extension Container` with `@Injected`/`@InjectedObject` and
`.onDebug(factory:)`.

Trial merge: 10 conflicted files, two of them `modify/delete` (`App/SessionController.swift`,
`App/SessionDependencies.swift`). Git resolved every file move correctly — only those two files
remain at stale paths — so the merge cost is compile-level API mismatch, not text:

| `feat/layout` uses | occurrences | `main` has instead |
| --- | --- | --- |
| `SessionController` | 13 in 7 files | `SessionMiddleware` owning connection + `*Requested` actions |
| `SessionDependencies` | 12 in 5 files | `extension Container` + `@InjectedObject(\.sessionStore)` |
| `SettingsController` / `settingsController()` / `settings.open` | 36 in 7 files | `SettingsFeature` actions + settings store |

Work inventory: **663 lines survive as-is** (Workspace domain + presentation components,
`ProjectListModel`, `ProjectGroup`), **~1 700 lines** are re-platformed or ported
(`WorkspaceController` 327 → middleware, containers/dependencies 281 → `@InjectedObject`, tests
and drivers), and `main`'s 597 lines of UI tests must keep passing.

## Ordered plan (each step ends green)

1. **Reconcile worktree.** Reset the scratch worktree to the new `main`, merge `feat/layout`
   `--no-commit`: drop `App/SessionController.swift` and `App/SessionDependencies.swift`, keep the
   `Projects/` and `Workspace/` slices, keep `main`'s `Session/`, `Settings/`, composer and
   middleware files.
2. **Re-home to the confirmed layout.** `Workspace/{WorkspaceContainer.swift, App/WorkspaceFeature.swift,
   Middleware/WorkspaceMiddleware.swift, Middleware/SessionTransport.swift, Domain/OpenSession.swift,
   UI/*}` and `Projects/{App,Domain}`; move the tests to `Tests/PiUITests/Workspace/{App,Middleware,UI}`.
3. **Container + settings re-platform** (first compiling step): `extension Container`
   factories for `sessionTransport`, `sessionStore` and `workspaceStore`; `@InjectedObject`
   containers; `SettingsFeature` dispatch/observe; delete the last `SettingsController` uses.
4. **Session slice trimmed to the conversation.** Remove connect/create from `SessionFeature`
   and `SessionMiddleware`; add `attachRequested`/`detachRequested` and the expected-session
   projection filter; port `SessionMiddlewareTests`/`SessionLifecycleTests` scenarios unchanged
   apart from the renamed connection entry point.
5. **`WorkspaceMiddleware`.** Move connect/catalogue/open/attach/switch/close/disconnect and the
   serialized selection loop plus `sessionEvents` handling; keep the eight `WorkspaceTabsTests`
   scenarios and `lateSelectionResultCannotOverwriteTheNewestChoice` green against it.
6. **Per-tab draft + composer binding.** Workspace `draftChanged`/`draftCleared(matching:)`;
   `SessionComposer`/`MacMessageEditor` take the draft binding; keep `canSend` derived from
   `session.canEditMessage` and a non-empty selected-tab draft.
7. **UI, shell, fixtures, drivers.** `WorkspacePane`/`SessionTabStrip` on `main`'s composer,
   follow-tail/anchor per tab, `MacWorkspacePaneRenderTests`, `pi_studioApp` (Window + one
   workspace store + `onDisappear` disconnect), `UITestConnection` (my catalogue/`PiSessionConnection`
   rewrite merged with `main`'s `delayedAdmission`), `PiUIDriver`, `UIProjectsDriver`,
   `pi_studioUITests`, `SettingsUITests`, `MultilineComposerUITests`.
8. **Verify and merge.** Run the matrix below, review commit by commit (~8 reviewable commits),
   then merge into `main` and remove the scratch worktree.

## Verification matrix

| Suite | Command | Gate |
| --- | --- | --- |
| Package | `pipeline_run piui` | Ported middleware tests, workspace reducer tests, tab scenarios, render test all pass |
| iOS unit | `pipeline_run ios-unit` | Pass |
| iOS UI | `pipeline_run ios-ui` | Pass, including `MultilineComposerUITests` and workspace browsing |
| macOS unit | `pipeline_run macos-unit` | Pass |
| macOS Release | `pipeline_run macos-release` | Builds |
| Mac layout | `MacWorkspacePaneRenderTests` PNG review | Tab strip matches revision 4 |
| macOS UI | `macos-ui` | **Paused by user request**; not a merge gate and not claimed |

SDK prerequisite is already satisfied: pi-chat `main` contains the switching/identity work
(`8364263`; 35 Swift + 155 TypeScript tests pass there), and `feat/layout`'s 57 PiUI tests pass
against that released checkout with no `PI_SDK_PATH` override.

## Open items

- `UITestConnection`: confirm it implements `PiSessionConnection` only (dropping the now-unused
  `connectDemo`) while keeping `main`'s `delayedAdmission` behaviour for the composer UI tests.
- `SessionConfiguration`: retire with the demo connect flow, or keep for the preview/demo path.
- Draft-clear bridge: the container-level `clearDraftMatching → draftCleared(matching:)` hop is
  view-driven. If that proves fragile, the fallback is to let `WorkspaceMiddleware` hold the
  session store and do it there (coupling one store into the other's middleware, which Flux 2
  does not support natively).
- Slices 3–5 (iPhone overview, background activity/unread, Needs you) continue on the reconciled
  base; `feat/pocket`'s foreground-recovery/steering work stays unstarted.
